#include "Limelight-internal.h"

#define TEST_PORT_TIMEOUT_SEC 3

#define VALID_PORT_FLAG_MASK (ML_PORT_FLAG_TCP_47984 | \
                              ML_PORT_FLAG_TCP_47989 | \
                              ML_PORT_FLAG_TCP_48010 | \
                              ML_PORT_FLAG_UDP_47998 | \
                              ML_PORT_FLAG_UDP_47999 | \
                              ML_PORT_FLAG_UDP_48000 | \
                              ML_PORT_FLAG_UDP_48010)

#define PORT_FLAGS_MAX_COUNT 32

#define MTU_TEST_SIZE 1040

unsigned int LiGetPortFlagsFromStage(int stage)
{
    switch (stage)
    {
        case STAGE_RTSP_HANDSHAKE:
            // GFE 3.22 requires a successful ping on 48000 to complete RTSP handshake
            return ML_PORT_FLAG_TCP_48010 | ML_PORT_FLAG_UDP_48010 | ML_PORT_FLAG_UDP_48000;

        case STAGE_CONTROL_STREAM_START:
            return ML_PORT_FLAG_UDP_47999;

        default:
            return 0;
    }
}

unsigned int LiGetPortFlagsFromTerminationErrorCode(int errorCode)
{
    switch (errorCode)
    {
        case ML_ERROR_NO_VIDEO_TRAFFIC:
            // Video is UDP 47998, but we'll also test UDP 48000 because
            // we don't have an equivalent audio traffic error.
            return ML_PORT_FLAG_UDP_47998 | ML_PORT_FLAG_UDP_48000;

        default:
            return 0;
    }
}

int LiGetProtocolFromPortFlagIndex(int portFlagIndex)
{
    // The lower byte is reserved for TCP
    return (portFlagIndex >= 8) ? IPPROTO_UDP : IPPROTO_TCP;
}

unsigned short LiGetPortFromPortFlagIndex(int portFlagIndex)
{
    switch (portFlagIndex)
    {
        // TCP ports
        case ML_PORT_INDEX_TCP_47984:
            return 47984;
        case ML_PORT_INDEX_TCP_47989:
            return 47989;
        case ML_PORT_INDEX_TCP_48010:
            return 48010;

        // UDP ports
        case ML_PORT_INDEX_UDP_47998:
            return 47998;
        case ML_PORT_INDEX_UDP_47999:
            return 47999;
        case ML_PORT_INDEX_UDP_48000:
            return 48000;
        case ML_PORT_INDEX_UDP_48010:
            return 48010;

        default:
            LC_ASSERT(false);
            return 0;
    }
}

void LiStringifyPortFlags(unsigned int portFlags, const char* separator, char* outputBuffer, int outputBufferLength)
{
    // Initialize the output buffer to an empty string
    outputBuffer[0] = 0;

    // If there is no separator specified, use an empty string
    if (separator == NULL) {
        separator = "";
    }

    int offset = 0;
    for (int i = 0; i < PORT_FLAGS_MAX_COUNT; i++) {
        if (portFlags & (1U << i)) {
            const char* protoStr = LiGetProtocolFromPortFlagIndex(i) == IPPROTO_UDP ? "UDP" : "TCP";
            offset += snprintf(&outputBuffer[offset], outputBufferLength - offset, "%s%s %u",
                               offset != 0 ? separator : "",
                               protoStr,
                               LiGetPortFromPortFlagIndex(i));
            if (outputBufferLength - offset <= 0) {
                // snprintf() will return the desired length if the buffer is too small,
                // so it is possible for this calculation to be negative.
                break;
            }
        }
    }
}

unsigned int LiTestClientConnectivity(const char* testServer, unsigned short referencePort, unsigned int testPortFlags)
{
    unsigned int failingPortFlags;
    struct sockaddr_storage address;
    SOCKADDR_LEN address_length;
    int i;
    int err;
    SOCKET sockets[PORT_FLAGS_MAX_COUNT];

    // Mask out invalid ports from the port flags
    testPortFlags &= VALID_PORT_FLAG_MASK;
    failingPortFlags = testPortFlags;

    // If no ports were specified, just return 0
    if (testPortFlags == 0) {
        return 0;
    }

    // Initialize sockets array to -1
    memset(sockets, 0xFF, sizeof(sockets));

    err = initializePlatformSockets();
    if (err != 0) {
        Limelog("Failed to initialize sockets: %d\n", err);
        return ML_TEST_RESULT_INCONCLUSIVE;
    }

    err = resolveHostName(testServer, AF_UNSPEC, TCP_PORT_FLAG_ALWAYS_TEST | referencePort, &address, &address_length);
    if (err != 0) {
        failingPortFlags = ML_TEST_RESULT_INCONCLUSIVE;
        goto Exit;
    }

    for (i = 0; i < PORT_FLAGS_MAX_COUNT; i++) {
        if (testPortFlags & (1U << i)) {
            sockets[i] = createSocket(address.ss_family,
                                      LiGetProtocolFromPortFlagIndex(i) == IPPROTO_UDP ? SOCK_DGRAM : SOCK_STREAM,
                                      LiGetProtocolFromPortFlagIndex(i),
                                      true);
            if (sockets[i] == INVALID_SOCKET) {
                err = LastSocketFail();
                Limelog("Failed to create socket: %d\n", err);
                failingPortFlags = ML_TEST_RESULT_INCONCLUSIVE;
                goto Exit;
            }

            SET_PORT((LC_SOCKADDR*)&address, LiGetPortFromPortFlagIndex(i));
            if (LiGetProtocolFromPortFlagIndex(i) == IPPROTO_TCP) {
                // Initiate an asynchronous connection
                err = connect(sockets[i], (struct sockaddr*)&address, address_length);
                if (err < 0) {
                    err = (int)LastSocketError();
                    if (err != EWOULDBLOCK && err != EAGAIN && err != EINPROGRESS) {
                        Limelog("Failed to start async connect to TCP %u: %d\n", LiGetPortFromPortFlagIndex(i), err);

                        // Mask off this bit so we don't try to include it in pollSockets() below
                        testPortFlags &= ~(1U << i);
                    }
                }
            }
            else {
                const char buf[MTU_TEST_SIZE] = "moonlight-ctest";
                int j;

                // Send a few packets since UDP is unreliable
                for (j = 0; j < 3; j++) {
                    err = sendto(sockets[i], buf, sizeof(buf), 0, (struct sockaddr*)&address, address_length);
                    if (err < 0) {
                        err = (int)LastSocketError();
                        Limelog("Failed to send test packet to UDP %u: %d\n", LiGetPortFromPortFlagIndex(i), err);

                        // Mask off this bit so we don't try to include it in pollSockets() below
                        testPortFlags &= ~(1U << i);

                        break;
                    }

                    PltSleepMs(50);
                }
            }
        }
    }

    // Continue to call pollSockets() until we have no more sockets to wait for,
    // or our pollSockets() call times out.
    while (testPortFlags != 0) {
        int nfds;
        struct pollfd pfds[PORT_FLAGS_MAX_COUNT];

        nfds = 0;

        // Fill out our FD sets
        for (i = 0; i < PORT_FLAGS_MAX_COUNT; i++) {
            if (testPortFlags & (1U << i)) {
                pfds[nfds].fd = sockets[i];

                if (LiGetProtocolFromPortFlagIndex(i) == IPPROTO_UDP) {
                    // Watch for readability on UDP sockets
                    pfds[nfds].events = POLLIN;
                }
                else {
                    // Watch for writeability on TCP sockets
                    pfds[nfds].events = POLLOUT;
                }

                nfds++;
            }
        }

        // Wait for the  to complete or the timeout to elapse.
        // NB: The timeout resets each time we get a valid response on a port,
        // but that's probably fine.
        err = pollSockets(pfds, nfds, TEST_PORT_TIMEOUT_SEC * 1000);
        if (err < 0) {
            // pollSockets() failed
            err = LastSocketError();
            Limelog("pollSockets() failed: %d\n", err);
            failingPortFlags = ML_TEST_RESULT_INCONCLUSIVE;
            goto Exit;
        }
        else if (err == 0) {
            // pollSockets() timed out
            Limelog("Connection timed out after %d seconds\n", TEST_PORT_TIMEOUT_SEC);
            break;
        }

        // We know something was signalled. Now we just need to find out what.
        for (i = 0; i < nfds; i++) {
            if (pfds[i].revents != 0) {
                int portIndex;

                // This socket was signalled. Figure out what port it was.
                for (portIndex = 0; portIndex < PORT_FLAGS_MAX_COUNT; portIndex++) {
                    if (sockets[portIndex] == pfds[i].fd) {
                        LC_ASSERT(testPortFlags & (1U << portIndex));
                        break;
                    }
                }

                LC_ASSERT(portIndex != PORT_FLAGS_MAX_COUNT);

                if (LiGetProtocolFromPortFlagIndex(portIndex) == IPPROTO_UDP) {
                    char buf[MTU_TEST_SIZE];

                    // A UDP socket was signalled. This could be because we got
                    // a packet from the test server, or it could be because we
                    // received an ICMP error which will be given to us from
                    // recvfrom().
                    testPortFlags &= ~(1U << portIndex);

                    // Check if the socket can be successfully read now
                    err = recvfrom(sockets[portIndex], buf, sizeof(buf), 0, NULL, NULL);
                    if (err >= 0) {
                        // The UDP test was a success.
                        failingPortFlags &= ~(1U << portIndex);

                        Limelog("UDP port %u test successful\n", LiGetPortFromPortFlagIndex(portIndex));
                    }
                    else {
                        err = LastSocketError();
                        Limelog("UDP port %u test failed: %d\n", LiGetPortFromPortFlagIndex(portIndex), err);
                    }
                }
                else {
                    // A TCP socket was signalled
                    SOCKADDR_LEN len = sizeof(err);
                    getsockopt(sockets[portIndex], SOL_SOCKET, SO_ERROR, (char*)&err, &len);
                    if (err != 0 || (pfds[i].revents & POLLERR)) {
                        // Get the error code
                        err = (err != 0) ? err : LastSocketFail();
                    }

                    // The TCP test has completed for this port
                    testPortFlags &= ~(1U << portIndex);
                    if (err == 0) {
                        // The TCP test was a success
                        failingPortFlags &= ~(1U << portIndex);

                        Limelog("TCP port %u test successful\n", LiGetPortFromPortFlagIndex(portIndex));
                    }
                    else {
                        Limelog("TCP port %u test failed: %d\n", LiGetPortFromPortFlagIndex(portIndex), err);
                    }
                }
            }
        }

        // Next iteration, we'll remove the matching sockets from our FD set and
        // call select() again to wait on the remaining sockets.
    }

Exit:
    for (i = 0; i < PORT_FLAGS_MAX_COUNT; i++) {
        if (sockets[i] != INVALID_SOCKET) {
            closeSocket(sockets[i]);
        }
    }

    cleanupPlatformSockets();
    return failingPortFlags;
}
