#include "Limelight-internal.h"
#include "rs.h"

#ifdef LC_DEBUG
// This enables FEC validation mode with a synthetic drop
// and recovered packet checks vs the original input. It
// is on by default for debug builds.
#define FEC_VALIDATION_MODE
#define FEC_VERBOSE
#endif

// Don't try speculative RFI for 5 minutes after seeing
// an out of order packet or incorrect prediction
#define SPECULATIVE_RFI_COOLDOWN_PERIOD_MS 300000

// RTP packets use a 90 KHz presentation timestamp clock
#define PTS_DIVISOR 90

void RtpvInitializeQueue(PRTP_VIDEO_QUEUE queue) {
    reed_solomon_init();
    memset(queue, 0, sizeof(*queue));

    queue->currentFrameNumber = 1;
    queue->multiFecCapable = APP_VERSION_AT_LEAST(7, 1, 431);
}

static void purgeListEntries(PRTPV_QUEUE_LIST list) {
    while (list->head != NULL) {
        PRTPV_QUEUE_ENTRY entry = list->head;
        list->head = entry->next;
        free(entry->packet);
    }

    list->tail = NULL;
    list->count = 0;
}

void RtpvCleanupQueue(PRTP_VIDEO_QUEUE queue) {
    purgeListEntries(&queue->pendingFecBlockList);
    purgeListEntries(&queue->completedFecBlockList);
}

static void insertEntryIntoList(PRTPV_QUEUE_LIST list, PRTPV_QUEUE_ENTRY entry) {
    LC_ASSERT(entry->prev == NULL);
    LC_ASSERT(entry->next == NULL);

    if (list->head == NULL) {
        LC_ASSERT(list->count == 0);
        LC_ASSERT(list->tail == NULL);
        list->head = list->tail = entry;
    }
    else {
        LC_ASSERT(list->count != 0);
        PRTPV_QUEUE_ENTRY oldTail = list->tail;
        entry->prev = oldTail;
        LC_ASSERT(oldTail->next == NULL);
        oldTail->next = entry;
        list->tail = entry;
    }

    list->count++;
}

static void removeEntryFromList(PRTPV_QUEUE_LIST list, PRTPV_QUEUE_ENTRY entry) {
    LC_ASSERT(entry != NULL);
    LC_ASSERT(list->count != 0);
    LC_ASSERT(list->head != NULL);
    LC_ASSERT(list->tail != NULL);

    if (list->head == entry) {
        list->head = entry->next;
    }
    if (list->tail == entry) {
        list->tail = entry->prev;
    }

    if (entry->prev != NULL) {
        LC_ASSERT(entry->prev->next == entry);
        entry->prev->next = entry->next;
    }
    if (entry->next != NULL) {
        LC_ASSERT(entry->next->prev == entry);
        entry->next->prev = entry->prev;
    }

    entry->next = NULL;
    entry->prev = NULL;

    list->count--;
}

static void reportFinalFrameFecStatus(PRTP_VIDEO_QUEUE queue) {
    SS_FRAME_FEC_STATUS fecStatus;
    
    fecStatus.frameIndex = BE32(queue->currentFrameNumber);
    fecStatus.highestReceivedSequenceNumber = BE16(queue->receivedHighestSequenceNumber);
    fecStatus.nextContiguousSequenceNumber = BE16(queue->nextContiguousSequenceNumber);
    fecStatus.missingPacketsBeforeHighestReceived = (uint8_t)queue->missingPackets;
    fecStatus.totalDataPackets = (uint8_t)queue->bufferDataPackets;
    fecStatus.totalParityPackets = (uint8_t)queue->bufferParityPackets;
    fecStatus.receivedDataPackets = (uint8_t)queue->receivedDataPackets;
    fecStatus.receivedParityPackets = (uint8_t)queue->receivedParityPackets;
    fecStatus.fecPercentage = (uint8_t)queue->fecPercentage;
    fecStatus.multiFecBlockIndex = (uint8_t)queue->multiFecCurrentBlockNumber;
    fecStatus.multiFecBlockCount = (uint8_t)(queue->multiFecLastBlockNumber + 1);
    
    connectionSendFrameFecStatus(&fecStatus);
}

// newEntry is contained within the packet buffer so we free the whole entry by freeing entry->packet
static bool queuePacket(PRTP_VIDEO_QUEUE queue, PRTPV_QUEUE_ENTRY newEntry, PRTP_PACKET packet, int length, bool isParity, bool isFecRecovery) {
    PRTPV_QUEUE_ENTRY entry;
    bool outOfSequence;
    
    LC_ASSERT(!(isFecRecovery && isParity));
    LC_ASSERT(!isBefore16(packet->sequenceNumber, queue->nextContiguousSequenceNumber));

    // If the packet is in order, we can take the fast path and avoid having
    // to loop through the whole list. If we get an out of order or missing
    // packet, the fast path will stop working and we'll use the loop instead.
    if (packet->sequenceNumber == queue->nextContiguousSequenceNumber) {
        queue->nextContiguousSequenceNumber = U16(packet->sequenceNumber + 1);

        // If we received the next contiguous sequence number but already have missing
        // packets, that means we received some later packets before falling back into
        // sequence with this one. By definition, that's OOS data so let's tag it.
        outOfSequence = queue->missingPackets != 0;
    }
    else {
        outOfSequence = false;

        // Check for duplicates
        entry = queue->pendingFecBlockList.head;
        while (entry != NULL) {
            if (packet->sequenceNumber == entry->packet->sequenceNumber) {
                return false;
            }
            else if (isBefore16(packet->sequenceNumber, entry->packet->sequenceNumber)) {
                outOfSequence = true;
            }

            entry = entry->next;
        }
    }

    newEntry->packet = packet;
    newEntry->length = length;
    newEntry->isParity = isParity;
    newEntry->prev = NULL;
    newEntry->next = NULL;
    newEntry->presentationTimeMs = packet->timestamp / PTS_DIVISOR;

    // FEC recovery packets are synthesized by us, so don't use them to determine OOS data
    if (!isFecRecovery) {
        if (outOfSequence) {
            // This packet was received after a higher sequence number packet, so note that we
            // received an out of order packet to disable our speculative RFI recovery logic.
            queue->lastOosFramePresentationTimestamp = newEntry->presentationTimeMs;
            if (!queue->receivedOosData) {
                Limelog("Leaving speculative RFI mode after OOS video data at frame %u\n",
                        queue->currentFrameNumber);
                queue->receivedOosData = true;
            }
        }
        else if (queue->receivedOosData && newEntry->presentationTimeMs > queue->lastOosFramePresentationTimestamp + SPECULATIVE_RFI_COOLDOWN_PERIOD_MS) {
            Limelog("Entering speculative RFI mode after sequenced video data at frame %u\n",
                    queue->currentFrameNumber);
            queue->receivedOosData = false;
        }
    }

    insertEntryIntoList(&queue->pendingFecBlockList, newEntry);

    return true;
}

#define PACKET_RECOVERY_FAILURE()                     \
    ret = -1;                                         \
    Limelog("FEC recovery returned corrupt packet %d" \
            " (frame %d)", rtpPacket->sequenceNumber, \
            queue->currentFrameNumber);               \
    free(packets[i]);                                 \
    continue

// Returns 0 if the frame is completely constructed
static int reconstructFrame(PRTP_VIDEO_QUEUE queue) {
    unsigned int totalPackets = queue->bufferDataPackets + queue->bufferParityPackets;
    unsigned int neededPackets = queue->bufferDataPackets;
    int ret;

    LC_ASSERT(totalPackets == U16(queue->bufferHighestSequenceNumber - queue->bufferLowestSequenceNumber) + 1U);
    
#ifdef FEC_VALIDATION_MODE
    // We'll need an extra packet to run in FEC validation mode, because we will
    // be "dropping" one below and recovering it using parity. However, some frames
    // are so large that FEC is disabled entirely, so don't wait for parity on those.
    neededPackets += queue->fecPercentage ? 1 : 0;
#endif

    LC_ASSERT(totalPackets - neededPackets <= queue->bufferParityPackets);

    if (queue->pendingFecBlockList.count < neededPackets) {
        // If we've never received OOS data from this host, we can predict whether this frame will be recoverable
        // based on the packets we've received (or not) so far. If the number of missing shards exceeds the total
        // needed shards, there is no hope of recovering the data. The only way we could recover this frame is by
        // receiving OOS data, which is unlikely because we've not seen any recently from this host.
        if (!queue->reportedLostFrame && !queue->receivedOosData) {
            // NB: We use totalPackets - neededPackets instead of just bufferParityPackets here because we require
            // one extra parity shard for recovery if we're in FEC validation mode.
            if (queue->missingPackets > totalPackets - neededPackets) {
                notifyFrameLost(queue->currentFrameNumber, true);
                queue->reportedLostFrame = true;
            }
            else {
                // Assert that there are enough remaining packets to possibly recover this frame.
                LC_ASSERT(neededPackets - queue->pendingFecBlockList.count <= U16(queue->bufferHighestSequenceNumber - queue->receivedHighestSequenceNumber));
            }
        }

        // Not enough data to recover yet
        return -1;
    }

    // If we make it here and reported a lost frame, we lied to the host. This can happen if we happen to get
    // unlucky and this particular frame happens to be the one with OOS data, but it should almost never happen.
    LC_ASSERT(queue->missingPackets <= queue->bufferParityPackets);
    LC_ASSERT(!queue->reportedLostFrame || queue->receivedOosData);
    if (queue->reportedLostFrame && !queue->receivedOosData) {
        // If it turns out that we lied to the host, stop further speculative RFI requests for a while.
        queue->receivedOosData = true;
        queue->lastOosFramePresentationTimestamp = queue->pendingFecBlockList.head->presentationTimeMs;
        Limelog("Leaving speculative RFI mode due to incorrect loss prediction of frame %u\n", queue->currentFrameNumber);
    }

#ifdef FEC_VALIDATION_MODE
    // If FEC is disabled or unsupported for this frame, we must bail early here.
    if ((queue->fecPercentage == 0 || AppVersionQuad[0] < 5) &&
            queue->receivedDataPackets == queue->bufferDataPackets) {
#else
    if (queue->receivedDataPackets == queue->bufferDataPackets) {
#endif
        // We've received a full frame with no need for FEC.
        return 0;
    }

    if (AppVersionQuad[0] < 5) {
        // Our FEC recovery code doesn't work properly until Gen 5
        Limelog("FEC recovery not supported on Gen %d servers\n",
                AppVersionQuad[0]);
        return -1;
    }

    reed_solomon* rs = NULL;
    unsigned char** packets = calloc(totalPackets, sizeof(unsigned char*));
    unsigned char* marks = calloc(totalPackets, sizeof(unsigned char));
    if (packets == NULL || marks == NULL) {
        ret = -2;
        goto cleanup;
    }
    
    rs = reed_solomon_new(queue->bufferDataPackets, queue->bufferParityPackets);
    
    // This could happen in an OOM condition, but it could also mean the FEC data
    // that we fed to reed_solomon_new() is bogus, so we'll assert to get a better look.
    LC_ASSERT(rs != NULL);
    if (rs == NULL) {
        ret = -3;
        goto cleanup;
    }
    
    memset(marks, 1, sizeof(char) * (totalPackets));
    
    int receiveSize = StreamConfig.packetSize + MAX_RTP_HEADER_SIZE;
    int packetBufferSize = receiveSize + sizeof(RTPV_QUEUE_ENTRY);

#ifdef FEC_VALIDATION_MODE
    // Choose a packet to drop
    unsigned int dropIndex = rand() % queue->bufferDataPackets;
    PRTP_PACKET droppedRtpPacket = NULL;
    int droppedRtpPacketLength = 0;
#endif

    PRTPV_QUEUE_ENTRY entry = queue->pendingFecBlockList.head;
    while (entry != NULL) {
        unsigned int index = U16(entry->packet->sequenceNumber - queue->bufferLowestSequenceNumber);

#ifdef FEC_VALIDATION_MODE
        if (index == dropIndex) {
            // If this was the drop choice, remember the original contents
            // and "drop" it.
            droppedRtpPacket = entry->packet;
            droppedRtpPacketLength = entry->length;
            entry = entry->next;
            continue;
        }
#endif

        packets[index] = (unsigned char*) entry->packet;
        marks[index] = 0;
        
        //Set padding to zero
        if (entry->length < receiveSize) {
            memset(&packets[index][entry->length], 0, receiveSize - entry->length);
        }

        entry = entry->next;
    }

    unsigned int i;
    for (i = 0; i < totalPackets; i++) {
        if (marks[i]) {
            packets[i] = malloc(packetBufferSize);
            if (packets[i] == NULL) {
                ret = -4;
                goto cleanup_packets;
            }
        }
    }
    
    ret = reed_solomon_reconstruct(rs, packets, marks, totalPackets, receiveSize);
    
    // We should always provide enough parity to recover the missing data successfully.
    // If this fails, something is probably wrong with our FEC state.
    LC_ASSERT(ret == 0);

    if (queue->bufferDataPackets != queue->receivedDataPackets) {
#ifdef FEC_VERBOSE
        Limelog("Recovered %d video data shards from frame %d\n",
                queue->bufferDataPackets - queue->receivedDataPackets,
                queue->currentFrameNumber);
#endif
        
        // Report the final FEC status if we needed to perform a recovery
        reportFinalFrameFecStatus(queue);
    }

cleanup_packets:
    for (i = 0; i < totalPackets; i++) {
        if (marks[i]) {
            // Only submit frame data, not FEC packets
            if (ret == 0 && i < queue->bufferDataPackets) {
                PRTPV_QUEUE_ENTRY queueEntry = (PRTPV_QUEUE_ENTRY)&packets[i][receiveSize];
                PRTP_PACKET rtpPacket = (PRTP_PACKET) packets[i];
                rtpPacket->sequenceNumber = U16(i + queue->bufferLowestSequenceNumber);
                rtpPacket->header = queue->pendingFecBlockList.head->packet->header;
                rtpPacket->timestamp = queue->pendingFecBlockList.head->packet->timestamp;
                rtpPacket->ssrc = queue->pendingFecBlockList.head->packet->ssrc;
                
                int dataOffset = sizeof(*rtpPacket);
                if (rtpPacket->header & FLAG_EXTENSION) {
                    dataOffset += 4; // 2 additional fields
                }

                PNV_VIDEO_PACKET nvPacket = (PNV_VIDEO_PACKET)(((char*)rtpPacket) + dataOffset);
                nvPacket->frameIndex = queue->currentFrameNumber;
                nvPacket->multiFecBlocks =
                        ((queue->multiFecLastBlockNumber << 2) | queue->multiFecCurrentBlockNumber) << 4;
                // TODO: nvPacket->multiFecFlags?

#ifdef FEC_VALIDATION_MODE
                if (i == dropIndex && droppedRtpPacket != NULL) {
                    // Check the packet contents if this was our known drop
                    PNV_VIDEO_PACKET droppedNvPacket = (PNV_VIDEO_PACKET)(((char*)droppedRtpPacket) + dataOffset);
                    int droppedDataLength = droppedRtpPacketLength - dataOffset - sizeof(*nvPacket);
                    int recoveredDataLength = StreamConfig.packetSize - sizeof(*nvPacket);
                    int j;
                    int recoveryErrors = 0;

                    LC_ASSERT(droppedDataLength <= recoveredDataLength);
                    LC_ASSERT(droppedDataLength == recoveredDataLength || (nvPacket->flags & FLAG_EOF));

                    // Check all NV_VIDEO_PACKET fields except FEC stuff which differs in the recovered packet
                    LC_ASSERT(nvPacket->flags == droppedNvPacket->flags);
                    LC_ASSERT(nvPacket->frameIndex == droppedNvPacket->frameIndex);
                    LC_ASSERT(nvPacket->streamPacketIndex == droppedNvPacket->streamPacketIndex);
                    LC_ASSERT(nvPacket->reserved == droppedNvPacket->reserved);
                    LC_ASSERT(!queue->multiFecCapable || nvPacket->multiFecBlocks == droppedNvPacket->multiFecBlocks);

                    // Check the data itself - use memcmp() and only loop if an error is detected
                    if (memcmp(nvPacket + 1, droppedNvPacket + 1, droppedDataLength)) {
                        unsigned char* actualData = (unsigned char*)(nvPacket + 1);
                        unsigned char* expectedData = (unsigned char*)(droppedNvPacket + 1);
                        for (j = 0; j < droppedDataLength; j++) {
                            if (actualData[j] != expectedData[j]) {
                                Limelog("Recovery error at %d: expected 0x%02x, actual 0x%02x\n",
                                        j, expectedData[j], actualData[j]);
                                recoveryErrors++;
                            }
                        }
                    }

                    // If this packet is at the end of the frame, the remaining data should be zeros.
                    for (j = droppedDataLength; j < recoveredDataLength; j++) {
                        unsigned char* actualData = (unsigned char*)(nvPacket + 1);
                        if (actualData[j] != 0) {
                            Limelog("Recovery error at %d: expected 0x00, actual 0x%02x\n",
                                    j, actualData[j]);
                            recoveryErrors++;
                        }
                    }

                    LC_ASSERT(recoveryErrors == 0);

                    // This drop was fake, so we don't want to actually submit it to the depacketizer.
                    // It will get confused because it's already seen this packet before.
                    free(packets[i]);
                    continue;
                }
#endif

                // Do some rudamentary checks to see that the recovered packet is sane.
                // In some cases (4K 30 FPS 80 Mbps), we seem to get some odd failures
                // here in rare cases where FEC recovery is required. I'm unsure if it
                // is our bug, NVIDIA's, or something else, but we don't want the corrupt
                // packet to by ingested by our depacketizer (or worse, the decoder).
                if (i == 0 && !(nvPacket->flags & FLAG_SOF)) {
                    PACKET_RECOVERY_FAILURE();
                }
                if (i == queue->bufferDataPackets - 1 && !(nvPacket->flags & FLAG_EOF)) {
                    PACKET_RECOVERY_FAILURE();
                }
                if (i > 0 && i < queue->bufferDataPackets - 1 && !(nvPacket->flags & FLAG_CONTAINS_PIC_DATA)) {
                    PACKET_RECOVERY_FAILURE();
                }
                if (nvPacket->flags & ~(FLAG_SOF | FLAG_EOF | FLAG_CONTAINS_PIC_DATA)) {
                    PACKET_RECOVERY_FAILURE();
                }

                // FEC recovered frames may have extra zero padding at the end. This is
                // fine per H.264 Annex B which states trailing zero bytes must be
                // discarded by decoders. It's not safe to strip all zero padding because
                // it may be a legitimate part of the H.264 bytestream.

                LC_ASSERT(isBefore16(rtpPacket->sequenceNumber, queue->bufferFirstParitySequenceNumber));
                queuePacket(queue, queueEntry, rtpPacket, StreamConfig.packetSize + dataOffset, false, true);
            } else if (packets[i] != NULL) {
                free(packets[i]);
            }
        }
    }

cleanup:
    reed_solomon_release(rs);

    if (packets != NULL)
        free(packets);

    if (marks != NULL)
        free(marks);
    
    return ret;
}

static void stageCompleteFecBlock(PRTP_VIDEO_QUEUE queue) {
    unsigned int nextSeqNum = queue->bufferLowestSequenceNumber;

    while (queue->pendingFecBlockList.count > 0) {
        PRTPV_QUEUE_ENTRY entry = queue->pendingFecBlockList.head;

        unsigned int lowestRtpSequenceNumber = entry->packet->sequenceNumber;

        while (entry != NULL) {
            // We should never encounter a packet that's lower than our next seq num
            LC_ASSERT(!isBefore16(entry->packet->sequenceNumber, nextSeqNum));

            // Never return parity packets
            if (entry->isParity) {
                PRTPV_QUEUE_ENTRY parityEntry = entry;

                // Skip this entry
                entry = parityEntry->next;

                // Remove this entry
                removeEntryFromList(&queue->pendingFecBlockList, parityEntry);

                // Free the entry and packet
                free(parityEntry->packet);

                continue;
            }

            // Check for the next packet in sequence. This will be O(1) for non-reordered packet streams.
            if (entry->packet->sequenceNumber == nextSeqNum) {
                removeEntryFromList(&queue->pendingFecBlockList, entry);

                // To avoid having to sample the system time for each packet, we cheat
                // and use the first packet's receive time for all packets. This ends up
                // actually being better for the measurements that the depacketizer does,
                // since it properly handles out of order packets.
                LC_ASSERT(queue->bufferFirstRecvTimeMs != 0);
                entry->receiveTimeMs = queue->bufferFirstRecvTimeMs;

                // Move this packet to the completed FEC block list
                insertEntryIntoList(&queue->completedFecBlockList, entry);
                break;
            }
            else if (isBefore16(entry->packet->sequenceNumber, lowestRtpSequenceNumber)) {
                lowestRtpSequenceNumber = entry->packet->sequenceNumber;
            }

            entry = entry->next;
        }

        if (entry == NULL) {
            // Start at the lowest we found last enumeration
            nextSeqNum = lowestRtpSequenceNumber;
        }
        else {
            // We found this packet so move on to the next one in sequence
            nextSeqNum = U16(nextSeqNum + 1);
        }
    }
}

static void submitCompletedFrame(PRTP_VIDEO_QUEUE queue) {
    while (queue->completedFecBlockList.count > 0) {
        PRTPV_QUEUE_ENTRY entry = queue->completedFecBlockList.head;

        // Parity packets should have been removed by stageCompleteFecBlock()
        LC_ASSERT(!entry->isParity);

        // Submit this packet for decoding. It will own freeing the entry now.
        removeEntryFromList(&queue->completedFecBlockList, entry);
        queueRtpPacket(entry);
    }
}

int RtpvAddPacket(PRTP_VIDEO_QUEUE queue, PRTP_PACKET packet, int length, PRTPV_QUEUE_ENTRY packetEntry) {
    if (isBefore16(packet->sequenceNumber, queue->nextContiguousSequenceNumber)) {
        // Reject packets behind our current buffer window
        return RTPF_RET_REJECTED;
    }

    // FLAG_EXTENSION is required for all supported versions of GFE.
    LC_ASSERT(packet->header & FLAG_EXTENSION);

    int dataOffset = sizeof(*packet);
    if (packet->header & FLAG_EXTENSION) {
        dataOffset += 4; // 2 additional fields
    }

    PNV_VIDEO_PACKET nvPacket = (PNV_VIDEO_PACKET)(((char*)packet) + dataOffset);

    nvPacket->streamPacketIndex = LE32(nvPacket->streamPacketIndex);
    nvPacket->frameIndex = LE32(nvPacket->frameIndex);
    nvPacket->fecInfo = LE32(nvPacket->fecInfo);

    // For legacy servers, we'll fixup the reserved data so that it looks like
    // it's a single FEC frame from a multi-FEC capable server. This allows us
    // to make our parsing logic simpler.
    if (!queue->multiFecCapable) {
        nvPacket->multiFecFlags = 0x10;
        nvPacket->multiFecBlocks = 0x00;
    }
    
    if (isBefore16(nvPacket->frameIndex, queue->currentFrameNumber)) {
        // Reject frames behind our current frame number
        return RTPF_RET_REJECTED;
    }

    uint32_t fecIndex = (nvPacket->fecInfo & 0x3FF000) >> 12;
    uint8_t fecCurrentBlockNumber = (nvPacket->multiFecBlocks >> 4) & 0x3;

    if (nvPacket->frameIndex == queue->currentFrameNumber && fecCurrentBlockNumber < queue->multiFecCurrentBlockNumber) {
        // Reject FEC blocks behind our current block number
        return RTPF_RET_REJECTED;
    }

    // Reinitialize the queue if it's empty after a frame delivery or
    // if we can't finish a frame before receiving the next one.
    if (queue->pendingFecBlockList.count == 0 || queue->currentFrameNumber != nvPacket->frameIndex ||
            queue->multiFecCurrentBlockNumber != fecCurrentBlockNumber) {
        if (queue->pendingFecBlockList.count != 0) {
            // Report the final status of the FEC queue before dropping this frame
            reportFinalFrameFecStatus(queue);

            if (queue->multiFecLastBlockNumber != 0) {
                Limelog("Unrecoverable frame %d (block %d of %d): %d+%d=%d received < %d needed\n",
                        queue->currentFrameNumber, queue->multiFecCurrentBlockNumber+1,
                        queue->multiFecLastBlockNumber+1,
                        queue->receivedDataPackets,
                        queue->receivedParityPackets,
                        queue->pendingFecBlockList.count,
                        queue->bufferDataPackets);

                // If we just missed a block of this frame rather than the whole thing,
                // we must manually advance the queue to the next frame. Parsing this
                // frame further is not possible.
                if (queue->currentFrameNumber == nvPacket->frameIndex) {
                    // Discard any unsubmitted buffers from the previous frame
                    purgeListEntries(&queue->pendingFecBlockList);
                    purgeListEntries(&queue->completedFecBlockList);

                    // Notify the host of the loss of this frame
                    if (!queue->reportedLostFrame) {
                        notifyFrameLost(queue->currentFrameNumber, false);
                        queue->reportedLostFrame = true;
                    }

                    queue->currentFrameNumber++;
                    queue->multiFecCurrentBlockNumber = 0;
                    return RTPF_RET_REJECTED;
                }
            }
            else {
                Limelog("Unrecoverable frame %d: %d+%d=%d received < %d needed\n",
                        queue->currentFrameNumber, queue->receivedDataPackets,
                        queue->receivedParityPackets,
                        queue->pendingFecBlockList.count,
                        queue->bufferDataPackets);
            }
        }
        
        // We must either start on the current FEC block number for the current frame,
        // or block 0 of a new frame.
        uint8_t expectedFecBlockNumber = (queue->currentFrameNumber == nvPacket->frameIndex ? queue->multiFecCurrentBlockNumber : 0);
        if (fecCurrentBlockNumber != expectedFecBlockNumber) {
            // Report the final status of the FEC queue before dropping this frame
            reportFinalFrameFecStatus(queue);

            Limelog("Unrecoverable frame %d: lost FEC blocks %d to %d\n",
                    nvPacket->frameIndex,
                    expectedFecBlockNumber + 1,
                    fecCurrentBlockNumber);

            // Discard any unsubmitted buffers from the previous frame
            purgeListEntries(&queue->pendingFecBlockList);
            purgeListEntries(&queue->completedFecBlockList);

            // Notify the host of the loss of this frame
            if (!queue->reportedLostFrame) {
                notifyFrameLost(queue->currentFrameNumber, false);
                queue->reportedLostFrame = true;
            }

            // We dropped a block of this frame, so we must skip to the next one.
            queue->currentFrameNumber = nvPacket->frameIndex + 1;
            queue->multiFecCurrentBlockNumber = 0;
            return RTPF_RET_REJECTED;
        }

        // Discard any pending buffers from the previous FEC block
        purgeListEntries(&queue->pendingFecBlockList);

        // Discard any completed FEC blocks from the previous frame
        if (queue->currentFrameNumber != nvPacket->frameIndex) {
            purgeListEntries(&queue->completedFecBlockList);
        }

        // If the frame numbers are not contiguous, the network dropped an entire frame.
        // The check here looks weird, but that's because we increment the frame number
        // after successfully processing a frame.
        if (queue->currentFrameNumber != nvPacket->frameIndex) {
            LC_ASSERT(queue->currentFrameNumber < nvPacket->frameIndex);

            // If the frame immediately preceding this one was lost, we may have already
            // reported it using our speculative RFI logic. Don't report it again.
            if (queue->currentFrameNumber + 1 != nvPacket->frameIndex || !queue->reportedLostFrame) {
                // NB: We only have to notify for the most recent lost frame, since
                // the depacketizer will report the RFI range starting at the last
                // frame it saw.
                notifyFrameLost(nvPacket->frameIndex - 1, false);
            }
        }

        queue->currentFrameNumber = nvPacket->frameIndex;

        // Tell the control stream logic about this frame, even if we don't end up
        // being able to reconstruct a full frame from it.
        connectionSawFrame(queue->currentFrameNumber);
        
        queue->bufferFirstRecvTimeMs = PltGetMillis();
        queue->bufferLowestSequenceNumber = U16(packet->sequenceNumber - fecIndex);
        queue->nextContiguousSequenceNumber = queue->bufferLowestSequenceNumber;
        queue->receivedDataPackets = 0;
        queue->receivedParityPackets = 0;
        queue->receivedHighestSequenceNumber = 0;
        queue->missingPackets = 0;
        queue->reportedLostFrame = false;
        queue->bufferDataPackets = (nvPacket->fecInfo & 0xFFC00000) >> 22;
        queue->fecPercentage = (nvPacket->fecInfo & 0xFF0) >> 4;
        queue->bufferParityPackets = (queue->bufferDataPackets * queue->fecPercentage + 99) / 100;
        queue->bufferFirstParitySequenceNumber = U16(queue->bufferLowestSequenceNumber + queue->bufferDataPackets);
        queue->bufferHighestSequenceNumber = U16(queue->bufferFirstParitySequenceNumber + queue->bufferParityPackets - 1);
        queue->multiFecCurrentBlockNumber = fecCurrentBlockNumber;
        queue->multiFecLastBlockNumber = (nvPacket->multiFecBlocks >> 6) & 0x3;
    } else if (isBefore16(queue->bufferHighestSequenceNumber, packet->sequenceNumber)) {
        // In rare cases, we get extra parity packets. It's rare enough that it's probably
        // not worth handling, so we'll just drop them.
        return RTPF_RET_REJECTED;
    }

    LC_ASSERT(!queue->fecPercentage || U16(packet->sequenceNumber - fecIndex) == queue->bufferLowestSequenceNumber);
    LC_ASSERT((nvPacket->fecInfo & 0xFF0) >> 4 == queue->fecPercentage);
    LC_ASSERT((nvPacket->fecInfo & 0xFFC00000) >> 22 == queue->bufferDataPackets);

    // Verify that the legacy non-multi-FEC compatibility code works
    LC_ASSERT(queue->multiFecCapable || fecCurrentBlockNumber == 0);
    LC_ASSERT(queue->multiFecCapable || queue->multiFecLastBlockNumber == 0);

    // Multi-block FEC details must remain the same within a single frame
    LC_ASSERT(fecCurrentBlockNumber == queue->multiFecCurrentBlockNumber);
    LC_ASSERT(((nvPacket->multiFecBlocks >> 6) & 0x3) == queue->multiFecLastBlockNumber);

    LC_ASSERT((nvPacket->flags & FLAG_EOF) || length - dataOffset == StreamConfig.packetSize);
    if (!queuePacket(queue, packetEntry, packet, length, !isBefore16(packet->sequenceNumber, queue->bufferFirstParitySequenceNumber), false)) {
        return RTPF_RET_REJECTED;
    }
    else {
        // Update total missing packet count
        if (queue->pendingFecBlockList.count == 1) {
            // Initialize counts and highest seqnum on the first packet
            LC_ASSERT(queue->missingPackets == 0);
            LC_ASSERT(queue->receivedHighestSequenceNumber == 0);
            queue->missingPackets += U16(packet->sequenceNumber - queue->bufferLowestSequenceNumber);
            queue->receivedHighestSequenceNumber = packet->sequenceNumber;
        }
        else if (isBefore16(queue->receivedHighestSequenceNumber, packet->sequenceNumber)) {
            // If we receive a packet above the highest sequence number,
            // adjust our missing packets count based on that new sequence number.
            queue->missingPackets += U16(packet->sequenceNumber - queue->receivedHighestSequenceNumber - 1);
            queue->receivedHighestSequenceNumber = packet->sequenceNumber;
        }
        else {
            // If we receive a packet behind the highest sequence number, but
            // queuePacket() accepted it, we must have received a missing packet.
            LC_ASSERT(queue->missingPackets > 0);
            queue->missingPackets--;
        }

        // We explicitly assert less-than because we know we received at least one packet (this one)
        LC_ASSERT(queue->missingPackets < queue->bufferDataPackets + queue->bufferParityPackets);

        if (isBefore16(packet->sequenceNumber, queue->bufferFirstParitySequenceNumber)) {
            queue->receivedDataPackets++;
            LC_ASSERT(queue->receivedDataPackets <= queue->bufferDataPackets);
        }
        else {
            queue->receivedParityPackets++;
            LC_ASSERT(queue->receivedParityPackets <= queue->bufferParityPackets);
        }
        
        // Try to submit this frame. If we haven't received enough packets,
        // this will fail and we'll keep waiting.
        if (reconstructFrame(queue) == 0) {
            // Stage the complete FEC block for use once reassembly is complete
            stageCompleteFecBlock(queue);
            
            // stageCompleteFecBlock() should have consumed all pending FEC data
            LC_ASSERT(queue->pendingFecBlockList.head == NULL);
            LC_ASSERT(queue->pendingFecBlockList.tail == NULL);
            LC_ASSERT(queue->pendingFecBlockList.count == 0);
            
            // If we're not yet at the last FEC block for this frame, move on to the next block.
            // Otherwise, the frame is complete and we can move on to the next frame.
            if (queue->multiFecCurrentBlockNumber < queue->multiFecLastBlockNumber) {
                // Move on to the next FEC block for this frame
                queue->multiFecCurrentBlockNumber++;
            }
            else {
                // Submit all FEC blocks to the depacketizer
                submitCompletedFrame(queue);

                // submitCompletedFrame() should have consumed all completed FEC data
                LC_ASSERT(queue->completedFecBlockList.head == NULL);
                LC_ASSERT(queue->completedFecBlockList.tail == NULL);
                LC_ASSERT(queue->completedFecBlockList.count == 0);

                // Continue to the next frame
                queue->currentFrameNumber++;
                queue->multiFecCurrentBlockNumber = 0;
            }
        }

        return RTPF_RET_QUEUED;
    }
}

