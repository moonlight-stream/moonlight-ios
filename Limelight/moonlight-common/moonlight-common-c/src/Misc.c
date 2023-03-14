#include "Limelight-internal.h"

#define ENET_INTERNAL_TIMEOUT_MS 100

// This function wraps enet_host_service() and hides the fact that it must be called
// multiple times for retransmissions to work correctly. It is meant to be a drop-in
// replacement for enet_host_service(). It also handles cancellation of the connection
// attempt during the wait.
static int serviceEnetHostInternal(ENetHost* client, ENetEvent* event, enet_uint32 timeoutMs, bool ignoreInterrupts) {
    int ret;

    // We need to call enet_host_service() multiple times to make sure retransmissions happen
    for (;;) {
        int selectedTimeout = timeoutMs < ENET_INTERNAL_TIMEOUT_MS ? timeoutMs : ENET_INTERNAL_TIMEOUT_MS;

        // We want to report an interrupt event if we are able to read data
        if (!ignoreInterrupts && ConnectionInterrupted) {
            Limelog("ENet wait interrupted\n");
            ret = -1;
            break;
        }

        ret = enet_host_service(client, event, selectedTimeout);
        if (ret != 0 || timeoutMs == 0) {
            break;
        }

        timeoutMs -= selectedTimeout;
    }

    return ret;
}

int serviceEnetHost(ENetHost* client, ENetEvent* event, enet_uint32 timeoutMs) {
    return serviceEnetHostInternal(client, event, timeoutMs, false);
}

// This function performs a graceful disconnect, including lingering until outbound
// traffic is acked (up until the linger timeout elapses).
int gracefullyDisconnectEnetPeer(ENetHost* host, ENetPeer* peer, enet_uint32 lingerTimeoutMs) {
    // Check if this peer is currently alive. We won't get another ENET_EVENT_TYPE_DISCONNECT
    // event from ENet if the peer is dead. In that case, we'll do an abortive disconnect.
    if (peer->state == ENET_PEER_STATE_CONNECTED) {
        ENetEvent event;
        int err;

        // Begin the disconnection process. We'll get ENET_EVENT_TYPE_DISCONNECT once
        // the peer acks all outstanding reliable sends.
        enet_peer_disconnect_later(peer, 0);

        // We must use the internal function which lets us ignore pending interrupts.
        while ((err = serviceEnetHostInternal(host, &event, lingerTimeoutMs, true)) > 0) {
            switch (event.type) {
            case ENET_EVENT_TYPE_RECEIVE:
                enet_packet_destroy(event.packet);
                break;
            case ENET_EVENT_TYPE_DISCONNECT:
                Limelog("ENet peer acknowledged disconnection\n");
                return 0;
            default:
                LC_ASSERT(false);
                break;
            }
        }

        if (err == 0) {
            Limelog("Timed out waiting for ENet peer to acknowledge disconnection\n");
        }
        else {
            Limelog("Failed to receive ENet peer disconnection acknowledgement\n");
        }

        return -1;
    }
    else {
        Limelog("ENet peer is already disconnected\n");
        enet_peer_disconnect_now(peer, 0);
        return 0;
    }
}

int extractVersionQuadFromString(const char* string, int* quad) {
    char versionString[128];
    char* nextDot;
    char* nextNumber;
    int i;
    
    strcpy(versionString, string);
    nextNumber = versionString;
    
    for (i = 0; i < 4; i++) {
        if (i == 3) {
            nextDot = strchr(nextNumber, '\0');
        }
        else {
            nextDot = strchr(nextNumber, '.');
        }
        if (nextDot == NULL) {
            return -1;
        }
        
        // Cut the string off at the next dot
        *nextDot = '\0';
        
        quad[i] = atoi(nextNumber);
        
        // Move on to the next segment
        nextNumber = nextDot + 1;
    }
    
    return 0;
}

void* extendBuffer(void* ptr, size_t newSize) {
    void* newBuf = realloc(ptr, newSize);
    if (newBuf == NULL && ptr != NULL) {
        free(ptr);
    }
    return newBuf;
}

bool isReferenceFrameInvalidationEnabled(void) {
    LC_ASSERT(NegotiatedVideoFormat != 0);

    // Even if the client wants it, we can't enable it without server support.
    if (!ReferenceFrameInvalidationSupported) {
        return false;
    }

    return ((NegotiatedVideoFormat & VIDEO_FORMAT_MASK_H264) && (VideoCallbacks.capabilities & CAPABILITY_REFERENCE_FRAME_INVALIDATION_AVC)) ||
           ((NegotiatedVideoFormat & VIDEO_FORMAT_MASK_H265) && (VideoCallbacks.capabilities & CAPABILITY_REFERENCE_FRAME_INVALIDATION_HEVC));
}

void LiInitializeStreamConfiguration(PSTREAM_CONFIGURATION streamConfig) {
    memset(streamConfig, 0, sizeof(*streamConfig));
}

void LiInitializeVideoCallbacks(PDECODER_RENDERER_CALLBACKS drCallbacks) {
    memset(drCallbacks, 0, sizeof(*drCallbacks));
}

void LiInitializeAudioCallbacks(PAUDIO_RENDERER_CALLBACKS arCallbacks) {
    memset(arCallbacks, 0, sizeof(*arCallbacks));
}

void LiInitializeConnectionCallbacks(PCONNECTION_LISTENER_CALLBACKS clCallbacks) {
    memset(clCallbacks, 0, sizeof(*clCallbacks));
}

void LiInitializeServerInformation(PSERVER_INFORMATION serverInfo) {
    memset(serverInfo, 0, sizeof(*serverInfo));
}

uint64_t LiGetMillis(void) {
    return PltGetMillis();
}
