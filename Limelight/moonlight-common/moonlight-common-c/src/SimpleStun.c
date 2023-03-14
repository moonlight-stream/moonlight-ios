#include "Limelight-internal.h"

#define STUN_RECV_TIMEOUT_SEC 3

#define STUN_MESSAGE_BINDING_REQUEST 0x0001
#define STUN_MESSAGE_BINDING_SUCCESS 0x0101
#define STUN_MESSAGE_COOKIE 0x2112a442

#define STUN_ATTRIBUTE_MAPPED_ADDRESS 0x0001
#define STUN_ATTRIBUTE_XOR_MAPPED_ADDRESS 0x0020

#pragma pack(push, 1)

typedef struct _STUN_ATTRIBUTE_HEADER {
    unsigned short type;
    unsigned short length;
} STUN_ATTRIBUTE_HEADER, *PSTUN_ATTRIBUTE_HEADER;

typedef struct _STUN_MAPPED_IPV4_ADDRESS_ATTRIBUTE {
    STUN_ATTRIBUTE_HEADER hdr;
    unsigned char reserved;
    unsigned char addressFamily;
    unsigned short port;
    unsigned int address;
} STUN_MAPPED_IPV4_ADDRESS_ATTRIBUTE, *PSTUN_MAPPED_IPV4_ADDRESS_ATTRIBUTE;

typedef struct _STUN_MESSAGE {
    unsigned short messageType;
    unsigned short messageLength;
    unsigned int magicCookie;
    unsigned char transactionId[12];
} STUN_MESSAGE, *PSTUN_MESSAGE;

#pragma pack(pop)

// This is extremely rudamentary STUN code simply for deriving the WAN IPv4 address when behind a NAT.
int LiFindExternalAddressIP4(const char* stunServer, unsigned short stunPort, unsigned int* wanAddr)
{
    SOCKET sock;
    struct addrinfo* stunAddrs;
    struct addrinfo hints;
    char stunPortStr[6];
    int err;
    STUN_MESSAGE reqMsg;
    int i;
    int bytesRead;
    PSTUN_ATTRIBUTE_HEADER attribute;
    PSTUN_MAPPED_IPV4_ADDRESS_ATTRIBUTE ipv4Attrib;
    union {
        STUN_MESSAGE hdr;
        char buf[1024];
    } resp;

    sock = INVALID_SOCKET;

    err = initializePlatformSockets();
    if (err != 0) {
        Limelog("Failed to initialize sockets: %d\n", err);
        return err;
    }

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;
    hints.ai_flags = AI_ADDRCONFIG;

    sprintf(stunPortStr, "%u", stunPort);
    err = getaddrinfo(stunServer, stunPortStr, &hints, &stunAddrs);
    if (err != 0 || stunAddrs == NULL) {
        Limelog("Failed to resolve STUN server: %d\n", err);
        stunAddrs = NULL;
        goto Exit;
    }

    sock = bindUdpSocket(hints.ai_family, 2048);
    if (sock == INVALID_SOCKET) {
        err = LastSocketFail();
        Limelog("Failed to connect to STUN server: %d\n", err);
        goto Exit;
    }

    reqMsg.messageType = htons(STUN_MESSAGE_BINDING_REQUEST);
    reqMsg.messageLength = 0;
    reqMsg.magicCookie = htonl(STUN_MESSAGE_COOKIE);
    PltGenerateRandomData(reqMsg.transactionId, sizeof(reqMsg.transactionId));

    bytesRead = SOCKET_ERROR;
    for (i = 0; i < STUN_RECV_TIMEOUT_SEC * 1000 / UDP_RECV_POLL_TIMEOUT_MS && bytesRead <= 0; i++) {
        // Retransmit the request every second until the timeout elapses or we get a response
        if (i % (1000 / UDP_RECV_POLL_TIMEOUT_MS) == 0) {
            struct addrinfo *current;

            // Send a request to each resolved address but stop if we get a response
            for (current = stunAddrs; current != NULL && bytesRead <= 0; current = current->ai_next) {
                err = (int)sendto(sock, (char *)&reqMsg, sizeof(reqMsg), 0, current->ai_addr, (SOCKADDR_LEN)current->ai_addrlen);
                if (err == SOCKET_ERROR) {
                    err = LastSocketFail();
                    Limelog("Failed to send STUN binding request: %d\n", err);
                    continue;
                }

                // Wait UDP_RECV_POLL_TIMEOUT_MS before moving on to the next server to
                // avoid having to spam the other STUN servers if we find a working one.
                bytesRead = recvUdpSocket(sock, resp.buf, sizeof(resp.buf), true);
            }
        }
        else {
            // This waits in UDP_RECV_POLL_TIMEOUT_MS increments
            bytesRead = recvUdpSocket(sock, resp.buf, sizeof(resp.buf), true);
        }
    }

    if (bytesRead == 0) {
        Limelog("No response from STUN server\n");
        err = -2;
        goto Exit;
    }
    else if (bytesRead == SOCKET_ERROR) {
        err = LastSocketFail();
        Limelog("Failed to read STUN binding response: %d\n", err);
        goto Exit;
    }
    else if (bytesRead < (int)sizeof(resp.hdr)) {
        Limelog("STUN message truncated: %d\n", bytesRead);
        err = -3;
        goto Exit;
    }
    else if (htonl(resp.hdr.magicCookie) != STUN_MESSAGE_COOKIE) {
        Limelog("Bad STUN cookie value: %x\n", htonl(resp.hdr.magicCookie));
        err = -3;
        goto Exit;
    }
    else if (memcmp(reqMsg.transactionId, resp.hdr.transactionId, sizeof(reqMsg.transactionId))) {
        Limelog("STUN transaction ID mismatch\n");
        err = -3;
        goto Exit;
    }
    else if (htons(resp.hdr.messageType) != STUN_MESSAGE_BINDING_SUCCESS) {
        Limelog("STUN message type mismatch: %x\n", htons(resp.hdr.messageType));
        err = -4;
        goto Exit;
    }

    attribute = (PSTUN_ATTRIBUTE_HEADER)(&resp.hdr + 1);
    bytesRead -= sizeof(resp.hdr);
    while (bytesRead > (int)sizeof(*attribute)) {
        if (bytesRead < (int)(sizeof(*attribute) + htons(attribute->length))) {
            Limelog("STUN attribute out of bounds: %d\n", htons(attribute->length));
            err = -5;
            goto Exit;
        }
        // Mask off the comprehension bit
        else if ((htons(attribute->type) & 0x7FFF) != STUN_ATTRIBUTE_XOR_MAPPED_ADDRESS) {
            // Continue searching if this wasn't our address
            bytesRead -= sizeof(*attribute) + htons(attribute->length);
            attribute = (PSTUN_ATTRIBUTE_HEADER)(((char*)attribute) + sizeof(*attribute) + htons(attribute->length));
            continue;
        }

        ipv4Attrib = (PSTUN_MAPPED_IPV4_ADDRESS_ATTRIBUTE)attribute;
        if (htons(ipv4Attrib->hdr.length) != 8) {
            Limelog("STUN address length mismatch: %d\n", htons(ipv4Attrib->hdr.length));
            err = -5;
            goto Exit;
        }
        else if (ipv4Attrib->addressFamily != 1) {
            Limelog("STUN address family mismatch: %x\n", ipv4Attrib->addressFamily);
            err = -5;
            goto Exit;
        }

        // The address is XORed with the cookie
        *wanAddr = ipv4Attrib->address ^ resp.hdr.magicCookie;

        err = 0;
        goto Exit;
    }

    Limelog("No XOR mapped address found in STUN response!\n");
    err = -6;

Exit:
    if (sock != INVALID_SOCKET) {
        closeSocket(sock);
    }

    if (stunAddrs != NULL) {
        freeaddrinfo(stunAddrs);
    }

    cleanupPlatformSockets();
    return err;
}
