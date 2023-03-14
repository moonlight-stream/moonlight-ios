#pragma once

#include "LinkedBlockingQueue.h"

typedef struct _QUEUED_DECODE_UNIT {
    DECODE_UNIT decodeUnit;
    LINKED_BLOCKING_QUEUE_ENTRY entry;
} QUEUED_DECODE_UNIT, *PQUEUED_DECODE_UNIT;

#pragma pack(push, 1)

#define FLAG_CONTAINS_PIC_DATA 0x1
#define FLAG_EOF 0x2
#define FLAG_SOF 0x4

typedef struct _NV_VIDEO_PACKET {
    uint32_t streamPacketIndex;
    uint32_t frameIndex;
    uint8_t flags;
    uint8_t reserved;
    uint8_t multiFecFlags;
    uint8_t multiFecBlocks;
    uint32_t fecInfo;
} NV_VIDEO_PACKET, *PNV_VIDEO_PACKET;

#define FLAG_EXTENSION 0x10

#define FIXED_RTP_HEADER_SIZE 12
#define MAX_RTP_HEADER_SIZE 16

typedef struct _RTP_PACKET {
    uint8_t header;
    uint8_t packetType;
    uint16_t sequenceNumber;
    uint32_t timestamp;
    uint32_t ssrc;
} RTP_PACKET, *PRTP_PACKET;

// Fields are big-endian
typedef struct _SS_PING {
    char payload[16];
    uint32_t sequenceNumber;
} SS_PING, *PSS_PING;

// Fields are big-endian
#define SS_FRAME_FEC_PTYPE 0x5501
typedef struct _SS_FRAME_FEC_STATUS {
    uint32_t frameIndex;
    uint16_t highestReceivedSequenceNumber;
    uint16_t nextContiguousSequenceNumber;
    uint8_t missingPacketsBeforeHighestReceived;
    uint8_t totalDataPackets;
    uint8_t totalParityPackets;
    uint8_t receivedDataPackets;
    uint8_t receivedParityPackets;
    uint8_t fecPercentage;
    uint8_t multiFecBlockIndex;
    uint8_t multiFecBlockCount;
} SS_FRAME_FEC_STATUS, *PSS_FRAME_FEC_STATUS;

#pragma pack(pop)
