#include "Limelight-internal.h"

#define MAX_OPTION_NAME_LEN 128

#define MAX_SDP_HEADER_LEN 128
#define MAX_SDP_TAIL_LEN 128

typedef struct _SDP_OPTION {
    char name[MAX_OPTION_NAME_LEN + 1];
    void* payload;
    int payloadLen;
    struct _SDP_OPTION* next;
} SDP_OPTION, *PSDP_OPTION;

// Cleanup the attribute list
static void freeAttributeList(PSDP_OPTION head) {
    PSDP_OPTION next;
    while (head != NULL) {
        next = head->next;
        free(head);
        head = next;
    }
}

// Get the size of the attribute list
static int getSerializedAttributeListSize(PSDP_OPTION head) {
    PSDP_OPTION currentEntry = head;
    size_t size = 0;
    while (currentEntry != NULL) {
        size += strlen("a=");
        size += strlen(currentEntry->name);
        size += strlen(":");
        size += currentEntry->payloadLen;
        size += strlen(" \r\n");

        currentEntry = currentEntry->next;
    }
    return (int)size;
}

// Populate the serialized attribute list into a string
static int fillSerializedAttributeList(char* buffer, PSDP_OPTION head) {
    PSDP_OPTION currentEntry = head;
    int offset = 0;
    while (currentEntry != NULL) {
        offset += sprintf(&buffer[offset], "a=%s:", currentEntry->name);
        memcpy(&buffer[offset], currentEntry->payload, currentEntry->payloadLen);
        offset += currentEntry->payloadLen;
        offset += sprintf(&buffer[offset], " \r\n");

        currentEntry = currentEntry->next;
    }
    return offset;
}

// Add an attribute
static int addAttributeBinary(PSDP_OPTION* head, char* name, const void* payload, int payloadLen) {
    PSDP_OPTION option, currentOption;

    option = malloc(sizeof(*option) + payloadLen);
    if (option == NULL) {
        return -1;
    }

    option->next = NULL;
    option->payloadLen = payloadLen;
    strcpy(option->name, name);
    option->payload = (void*)(option + 1);
    memcpy(option->payload, payload, payloadLen);

    if (*head == NULL) {
        *head = option;
    }
    else {
        currentOption = *head;
        while (currentOption->next != NULL) {
            currentOption = currentOption->next;
        }
        currentOption->next = option;
    }

    return 0;
}

// Add an attribute string
static int addAttributeString(PSDP_OPTION* head, char* name, const char* payload) {
    // We purposefully omit the null terminating character
    return addAttributeBinary(head, name, payload, (int)strlen(payload));
}

static int addGen3Options(PSDP_OPTION* head, char* addrStr) {
    int payloadInt;
    int err = 0;

    err |= addAttributeString(head, "x-nv-general.serverAddress", addrStr);

    payloadInt = htonl(0x42774141);
    err |= addAttributeBinary(head,
        "x-nv-general.featureFlags", &payloadInt, sizeof(payloadInt));

    payloadInt = htonl(0x41514141);
    err |= addAttributeBinary(head,
        "x-nv-video[0].transferProtocol", &payloadInt, sizeof(payloadInt));
    err |= addAttributeBinary(head,
        "x-nv-video[1].transferProtocol", &payloadInt, sizeof(payloadInt));
    err |= addAttributeBinary(head,
        "x-nv-video[2].transferProtocol", &payloadInt, sizeof(payloadInt));
    err |= addAttributeBinary(head,
        "x-nv-video[3].transferProtocol", &payloadInt, sizeof(payloadInt));

    payloadInt = htonl(0x42414141);
    err |= addAttributeBinary(head,
        "x-nv-video[0].rateControlMode", &payloadInt, sizeof(payloadInt));
    payloadInt = htonl(0x42514141);
    err |= addAttributeBinary(head,
        "x-nv-video[1].rateControlMode", &payloadInt, sizeof(payloadInt));
    err |= addAttributeBinary(head,
        "x-nv-video[2].rateControlMode", &payloadInt, sizeof(payloadInt));
    err |= addAttributeBinary(head,
        "x-nv-video[3].rateControlMode", &payloadInt, sizeof(payloadInt));

    err |= addAttributeString(head, "x-nv-vqos[0].bw.flags", "14083");

    err |= addAttributeString(head, "x-nv-vqos[0].videoQosMaxConsecutiveDrops", "0");
    err |= addAttributeString(head, "x-nv-vqos[1].videoQosMaxConsecutiveDrops", "0");
    err |= addAttributeString(head, "x-nv-vqos[2].videoQosMaxConsecutiveDrops", "0");
    err |= addAttributeString(head, "x-nv-vqos[3].videoQosMaxConsecutiveDrops", "0");

    return err;
}

static int addGen4Options(PSDP_OPTION* head, char* addrStr) {
    char payloadStr[92];
    int err = 0;

    LC_ASSERT(RtspPortNumber != 0);
    sprintf(payloadStr, "rtsp://%s:%u", addrStr, RtspPortNumber);
    err |= addAttributeString(head, "x-nv-general.serverAddress", payloadStr);

    return err;
}

#define NVFF_BASE             0x07
#define NVFF_AUDIO_ENCRYPTION 0x20
#define NVFF_RI_ENCRYPTION    0x80

static int addGen5Options(PSDP_OPTION* head) {
    int err = 0;
    char payloadStr[32];

    // This must be initialized to false already
    LC_ASSERT(!AudioEncryptionEnabled);

    if (APP_VERSION_AT_LEAST(7, 1, 431)) {
        unsigned int featureFlags;

        // RI encryption is always enabled
        featureFlags = NVFF_BASE | NVFF_RI_ENCRYPTION;

        // Enable audio encryption if the client opted in
        if (StreamConfig.encryptionFlags & ENCFLG_AUDIO) {
            featureFlags |= NVFF_AUDIO_ENCRYPTION;
            AudioEncryptionEnabled = true;
        }

        sprintf(payloadStr, "%u", featureFlags);
        err |= addAttributeString(head, "x-nv-general.featureFlags", payloadStr);

        // Ask for the encrypted control protocol to ensure remote input will be encrypted.
        // This used to be done via separate RI encryption, but now it is all or nothing.
        err |= addAttributeString(head, "x-nv-general.useReliableUdp", "13");

        // Require at least 2 FEC packets for small frames. If a frame has fewer data shards
        // than would generate 2 FEC shards, it will increase the FEC percentage for that frame
        // above the set value (even going as high as 200% FEC to generate 2 FEC shards from a
        // 1 data shard frame).
        err |= addAttributeString(head, "x-nv-vqos[0].fec.minRequiredFecPackets", "2");

        // BLL-FEC appears to adjust dynamically based on the loss rate and instantaneous bitrate
        // of each frame, however we can't dynamically control it from our side yet. As a result,
        // the effective FEC amount is significantly lower (single digit percentages for many
        // large frames) and the result is worse performance during packet loss. Disabling BLL-FEC
        // results in GFE 3.26 falling back to the legacy FEC method as we would like.
        err |= addAttributeString(head, "x-nv-vqos[0].bllFec.enable", "0");
    }
    else {
        // We want to use the new ENet connections for control and input
        err |= addAttributeString(head, "x-nv-general.useReliableUdp", "1");
        err |= addAttributeString(head, "x-nv-ri.useControlChannel", "1");

        // When streaming 4K, lower FEC levels to reduce stream overhead
        if (StreamConfig.width >= 3840 && StreamConfig.height >= 2160) {
            err |= addAttributeString(head, "x-nv-vqos[0].fec.repairPercent", "5");
        }
        else {
            err |= addAttributeString(head, "x-nv-vqos[0].fec.repairPercent", "20");
        }
    }
    
    if (APP_VERSION_AT_LEAST(7, 1, 446) && (StreamConfig.width < 720 || StreamConfig.height < 540)) {
        // We enable DRC with a static DRC table for very low resoutions on GFE 3.26 to work around
        // a bug that causes nvstreamer.exe to crash due to failing to populate a list of valid resolutions.
        //
        // Despite the fact that the DRC table doesn't include our target streaming resolution, we still
        // seem to stream at the target resolution, presumably because we don't send control data to tell
        // the host otherwise.
        err |= addAttributeString(head, "x-nv-vqos[0].drc.enable", "1");
        err |= addAttributeString(head, "x-nv-vqos[0].drc.tableType", "2");
    }
    else {
        // Disable dynamic resolution switching
        err |= addAttributeString(head, "x-nv-vqos[0].drc.enable", "0");
    }

    // Recovery mode can cause the FEC percentage to change mid-frame, which
    // breaks many assumptions in RTP FEC queue.
    err |= addAttributeString(head, "x-nv-general.enableRecoveryMode", "0");

    return err;
}

static PSDP_OPTION getAttributesList(char*urlSafeAddr) {
    PSDP_OPTION optionHead;
    char payloadStr[92];
    int audioChannelCount;
    int audioChannelMask;
    int err;
    int bitrate;

    // This must have been resolved to either local or remote by now
    LC_ASSERT(StreamConfig.streamingRemotely != STREAM_CFG_AUTO);

    optionHead = NULL;
    err = 0;

    sprintf(payloadStr, "%d", StreamConfig.width);
    err |= addAttributeString(&optionHead, "x-nv-video[0].clientViewportWd", payloadStr);
    sprintf(payloadStr, "%d", StreamConfig.height);
    err |= addAttributeString(&optionHead, "x-nv-video[0].clientViewportHt", payloadStr);

    sprintf(payloadStr, "%d", StreamConfig.fps);
    err |= addAttributeString(&optionHead, "x-nv-video[0].maxFPS", payloadStr);

    sprintf(payloadStr, "%d", StreamConfig.packetSize);
    err |= addAttributeString(&optionHead, "x-nv-video[0].packetSize", payloadStr);

    err |= addAttributeString(&optionHead, "x-nv-video[0].rateControlMode", "4");

    err |= addAttributeString(&optionHead, "x-nv-video[0].timeoutLengthMs", "7000");
    err |= addAttributeString(&optionHead, "x-nv-video[0].framesWithInvalidRefThreshold", "0");

    // Use more strict bitrate logic when streaming remotely. The theory here is that remote
    // streaming is much more bandwidth sensitive. Someone might select 5 Mbps because that's
    // really all they have, so we need to be careful not to exceed the cap, even counting
    // things like audio and control data.
    if (StreamConfig.streamingRemotely == STREAM_CFG_REMOTE) {
        // 20% of the video bitrate will added to the user-specified bitrate for FEC
        bitrate = (int)(OriginalVideoBitrate * 0.80);

        // Subtract 500 Kbps to leave room for audio and control. On remote streams,
        // GFE will use 96Kbps stereo audio. For local streams, it will choose 512Kbps.
        if (bitrate > 500) {
            bitrate -= 500;
        }
    }
    else {
        bitrate = StreamConfig.bitrate;
    }

    // If the calculated bitrate (with the HEVC multiplier in effect) is less than this,
    // use the lower of the two bitrate values.
    bitrate = StreamConfig.bitrate < bitrate ? StreamConfig.bitrate : bitrate;

    // GFE currently imposes a limit of 100 Mbps for the video bitrate. It will automatically
    // impose that on maximumBitrateKbps but not on initialBitrateKbps. We will impose the cap
    // ourselves so initialBitrateKbps does not exceed maximumBitrateKbps.
    bitrate = bitrate > 100000 ? 100000 : bitrate;

    // We don't support dynamic bitrate scaling properly (it tends to bounce between min and max and never
    // settle on the optimal bitrate if it's somewhere in the middle), so we'll just latch the bitrate
    // to the requested value.
    if (AppVersionQuad[0] >= 5) {
        sprintf(payloadStr, "%d", bitrate);

        err |= addAttributeString(&optionHead, "x-nv-video[0].initialBitrateKbps", payloadStr);
        err |= addAttributeString(&optionHead, "x-nv-video[0].initialPeakBitrateKbps", payloadStr);

        err |= addAttributeString(&optionHead, "x-nv-vqos[0].bw.minimumBitrateKbps", payloadStr);
        err |= addAttributeString(&optionHead, "x-nv-vqos[0].bw.maximumBitrateKbps", payloadStr);
    }
    else {
        if (StreamConfig.streamingRemotely == STREAM_CFG_REMOTE) {
            err |= addAttributeString(&optionHead, "x-nv-video[0].averageBitrate", "4");
            err |= addAttributeString(&optionHead, "x-nv-video[0].peakBitrate", "4");
        }

        sprintf(payloadStr, "%d", bitrate);
        err |= addAttributeString(&optionHead, "x-nv-vqos[0].bw.minimumBitrate", payloadStr);
        err |= addAttributeString(&optionHead, "x-nv-vqos[0].bw.maximumBitrate", payloadStr);
    }
    
    // FEC must be enabled for proper packet sequencing to be done by RTP FEC queue
    err |= addAttributeString(&optionHead, "x-nv-vqos[0].fec.enable", "1");
    
    err |= addAttributeString(&optionHead, "x-nv-vqos[0].videoQualityScoreUpdateTime", "5000");

    // If the remote host is local (RFC 1918), enable QoS tagging for our traffic. Windows qWave
    // will disable it if the host is off-link, *however* Windows may get it wrong in cases where
    // the host is directly connected to the Internet without a NAT. In this case, it may send DSCP
    // marked traffic off-link and it could lead to black holes due to misconfigured ISP hardware
    // or CPE. For this reason, we only enable it in cases where it looks like it will work.
    //
    // Even though IPv6 hardware should be much less likely to have this issue, we can't tell
    // if our address is a NAT64 synthesized IPv6 address or true end-to-end IPv6. If it's the
    // former, it may have the same problem as other IPv4 traffic.
    if (StreamConfig.streamingRemotely == STREAM_CFG_LOCAL) {
        err |= addAttributeString(&optionHead, "x-nv-vqos[0].qosTrafficType", "5");
        err |= addAttributeString(&optionHead, "x-nv-aqos.qosTrafficType", "4");
    }
    else {
        err |= addAttributeString(&optionHead, "x-nv-vqos[0].qosTrafficType", "0");
        err |= addAttributeString(&optionHead, "x-nv-aqos.qosTrafficType", "0");
    }

    if (AppVersionQuad[0] == 3) {
        err |= addGen3Options(&optionHead, urlSafeAddr);
    }
    else if (AppVersionQuad[0] == 4) {
        err |= addGen4Options(&optionHead, urlSafeAddr);
    }
    else {
        err |= addGen5Options(&optionHead);
    }

    audioChannelCount = CHANNEL_COUNT_FROM_AUDIO_CONFIGURATION(StreamConfig.audioConfiguration);
    audioChannelMask = CHANNEL_MASK_FROM_AUDIO_CONFIGURATION(StreamConfig.audioConfiguration);

    if (AppVersionQuad[0] >= 4) {
        unsigned char slicesPerFrame;

        // Use slicing for increased performance on some decoders
        slicesPerFrame = (unsigned char)(VideoCallbacks.capabilities >> 24);
        if (slicesPerFrame == 0) {
            // If not using slicing, we request 1 slice per frame
            slicesPerFrame = 1;
        }
        sprintf(payloadStr, "%d", slicesPerFrame);
        err |= addAttributeString(&optionHead, "x-nv-video[0].videoEncoderSlicesPerFrame", payloadStr);

        if (NegotiatedVideoFormat & VIDEO_FORMAT_MASK_H265) {
            err |= addAttributeString(&optionHead, "x-nv-clientSupportHevc", "1");
            err |= addAttributeString(&optionHead, "x-nv-vqos[0].bitStreamFormat", "1");

            if (AppVersionQuad[0] >= 7) {
                // Enable HDR if requested
                if (StreamConfig.enableHdr) {
                    err |= addAttributeString(&optionHead, "x-nv-video[0].dynamicRangeMode", "1");
                }
                else {
                    err |= addAttributeString(&optionHead, "x-nv-video[0].dynamicRangeMode", "0");
                }
            }

            if (!APP_VERSION_AT_LEAST(7, 1, 408)) {
                // This disables split frame encode on GFE 3.10 which seems to produce broken
                // HEVC output at 1080p60 (full of artifacts even on the SHIELD itself, go figure).
                // It now appears to work fine on GFE 3.14.1.
                Limelog("Disabling split encode for HEVC on older GFE version");
                err |= addAttributeString(&optionHead, "x-nv-video[0].encoderFeatureSetting", "0");
            }
        }
        else {
            
            err |= addAttributeString(&optionHead, "x-nv-clientSupportHevc", "0");
            err |= addAttributeString(&optionHead, "x-nv-vqos[0].bitStreamFormat", "0");

            if (AppVersionQuad[0] >= 7) {
                // HDR is not supported on H.264
                err |= addAttributeString(&optionHead, "x-nv-video[0].dynamicRangeMode", "0");
            }

            // We shouldn't be able to reach this path with enableHdr set. If we did, that means
            // the server or client doesn't support HEVC and the client didn't do the correct checks
            // before requesting HDR streaming.
            LC_ASSERT(!StreamConfig.enableHdr);
        }

        if (AppVersionQuad[0] >= 7) {
            if (isReferenceFrameInvalidationEnabled()) {
                err |= addAttributeString(&optionHead, "x-nv-video[0].maxNumReferenceFrames", "0");
            }
            else {
                // Restrict the video stream to 1 reference frame if we're not using
                // reference frame invalidation. This helps to improve compatibility with
                // some decoders that don't like the default of having 16 reference frames.
                err |= addAttributeString(&optionHead, "x-nv-video[0].maxNumReferenceFrames", "1");
            }

            sprintf(payloadStr, "%d", StreamConfig.clientRefreshRateX100);
            err |= addAttributeString(&optionHead, "x-nv-video[0].clientRefreshRateX100", payloadStr);
        }

        sprintf(payloadStr, "%d", audioChannelCount);
        err |= addAttributeString(&optionHead, "x-nv-audio.surround.numChannels", payloadStr);
        sprintf(payloadStr, "%d", audioChannelMask);
        err |= addAttributeString(&optionHead, "x-nv-audio.surround.channelMask", payloadStr);
        if (audioChannelCount > 2) {
            err |= addAttributeString(&optionHead, "x-nv-audio.surround.enable", "1");
        }
        else {
            err |= addAttributeString(&optionHead, "x-nv-audio.surround.enable", "0");
        }
    }

    if (AppVersionQuad[0] >= 7) {
        // Decide to use HQ audio based on the original video bitrate, not the HEVC-adjusted value
        if (OriginalVideoBitrate >= HIGH_AUDIO_BITRATE_THRESHOLD && audioChannelCount > 2 &&
                HighQualitySurroundSupported && (AudioCallbacks.capabilities & CAPABILITY_SLOW_OPUS_DECODER) == 0) {
            // Enable high quality mode for surround sound
            err |= addAttributeString(&optionHead, "x-nv-audio.surround.AudioQuality", "1");

            // Let the audio stream code know that it needs to disable coupled streams when
            // decoding this audio stream.
            HighQualitySurroundEnabled = true;

            // Use 5 ms frames since we don't have a slow decoder
            AudioPacketDuration = 5;
        }
        else {
            err |= addAttributeString(&optionHead, "x-nv-audio.surround.AudioQuality", "0");
            HighQualitySurroundEnabled = false;

            if ((AudioCallbacks.capabilities & CAPABILITY_SLOW_OPUS_DECODER) ||
                     ((AudioCallbacks.capabilities & CAPABILITY_SUPPORTS_ARBITRARY_AUDIO_DURATION) != 0 &&
                       OriginalVideoBitrate < LOW_AUDIO_BITRATE_TRESHOLD)) {
                // Use 10 ms packets for slow devices and networks to balance latency and bandwidth usage
                AudioPacketDuration = 10;
            }
            else {
                // Use 5 ms packets by default for lowest latency
                AudioPacketDuration = 5;
            }
        }

        sprintf(payloadStr, "%d", AudioPacketDuration);
        err |= addAttributeString(&optionHead, "x-nv-aqos.packetDuration", payloadStr);
    }
    else {
        // 5 ms duration for legacy servers
        AudioPacketDuration = 5;

        // High quality audio mode not supported on legacy servers
        HighQualitySurroundEnabled = false;
    }

    if (AppVersionQuad[0] >= 7) {
        sprintf(payloadStr, "%d", (StreamConfig.colorSpace << 1) | StreamConfig.colorRange);
        err |= addAttributeString(&optionHead, "x-nv-video[0].encoderCscMode", payloadStr);
    }

    if (err == 0) {
        return optionHead;
    }

    freeAttributeList(optionHead);
    return NULL;
}

// Populate the SDP header with required information
static int fillSdpHeader(char* buffer, int rtspClientVersion, char*urlSafeAddr) {
    return sprintf(buffer,
        "v=0\r\n"
        "o=android 0 %d IN %s %s\r\n"
        "s=NVIDIA Streaming Client\r\n",
        rtspClientVersion,
        RemoteAddr.ss_family == AF_INET ? "IPv4" : "IPv6",
        urlSafeAddr);
}

// Populate the SDP tail with required information
static int fillSdpTail(char* buffer) {
    LC_ASSERT(VideoPortNumber != 0);
    return sprintf(buffer,
        "t=0 0\r\n"
        "m=video %d  \r\n",
        AppVersionQuad[0] < 4 ? 47996 : VideoPortNumber);
}

// Get the SDP attributes for the stream config
char* getSdpPayloadForStreamConfig(int rtspClientVersion, int* length) {
    PSDP_OPTION attributeList;
    int offset;
    char* payload;
    char urlSafeAddr[URLSAFESTRING_LEN];

    addrToUrlSafeString(&RemoteAddr, urlSafeAddr);

    attributeList = getAttributesList(urlSafeAddr);
    if (attributeList == NULL) {
        return NULL;
    }

    payload = malloc(MAX_SDP_HEADER_LEN + MAX_SDP_TAIL_LEN +
        getSerializedAttributeListSize(attributeList));
    if (payload == NULL) {
        freeAttributeList(attributeList);
        return NULL;
    }

    offset = fillSdpHeader(payload, rtspClientVersion, urlSafeAddr);
    offset += fillSerializedAttributeList(&payload[offset], attributeList);
    offset += fillSdpTail(&payload[offset]);

    freeAttributeList(attributeList);
    *length = offset;
    return payload;
}
