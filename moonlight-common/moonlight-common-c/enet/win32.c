/** 
 @file  win32.c
 @brief ENet Win32 system specific functions
*/
#ifdef _WIN32

#define ENET_BUILDING_LIB 1
#include "enet/enet.h"
#include <windows.h>
#include <Mswsock.h>
#ifndef HAS_QOS_FLOWID
typedef UINT32 QOS_FLOWID;
#endif
#ifndef HAS_PQOS_FLOWID
typedef UINT32 *PQOS_FLOWID;
#endif
#include <mmsystem.h>
#include <qos2.h>
#ifndef QOS_NON_ADAPTIVE_FLOW
#define QOS_NON_ADAPTIVE_FLOW 0x00000002
#endif

static enet_uint32 timeBase = 0;
static HANDLE qosHandle = INVALID_HANDLE_VALUE;
static QOS_FLOWID qosFlowId;
static BOOL qosAddedFlow;

static HMODULE QwaveLibraryHandle;

BOOL (WINAPI *pfnQOSCreateHandle)(PQOS_VERSION Version, PHANDLE QOSHandle);
BOOL (WINAPI *pfnQOSCloseHandle)(HANDLE QOSHandle);
BOOL (WINAPI *pfnQOSAddSocketToFlow)(HANDLE QOSHandle, SOCKET Socket, PSOCKADDR DestAddr, QOS_TRAFFIC_TYPE TrafficType, DWORD Flags, PQOS_FLOWID FlowId);

LPFN_WSARECVMSG pfnWSARecvMsg;

int
enet_initialize (void)
{
    WORD versionRequested = MAKEWORD (2, 0);
    WSADATA wsaData;
   
    if (WSAStartup (versionRequested, & wsaData))
       return -1;

    if (LOBYTE (wsaData.wVersion) != 2||
        HIBYTE (wsaData.wVersion) != 0)
    {
       WSACleanup ();
       
       return -1;
    }

    timeBeginPeriod (1);

    QwaveLibraryHandle = LoadLibraryA("qwave.dll");
    if (QwaveLibraryHandle != NULL) {
        pfnQOSCreateHandle = (void*)GetProcAddress(QwaveLibraryHandle, "QOSCreateHandle");
        pfnQOSCloseHandle = (void*)GetProcAddress(QwaveLibraryHandle, "QOSCloseHandle");
        pfnQOSAddSocketToFlow = (void*)GetProcAddress(QwaveLibraryHandle, "QOSAddSocketToFlow");

        if (pfnQOSCreateHandle == NULL || pfnQOSCloseHandle == NULL || pfnQOSAddSocketToFlow == NULL) {
            pfnQOSCreateHandle = NULL;
            pfnQOSCloseHandle = NULL;
            pfnQOSAddSocketToFlow = NULL;

            FreeLibrary(QwaveLibraryHandle);
            QwaveLibraryHandle = NULL;
        }
    }

    return 0;
}

void
enet_deinitialize (void)
{
    qosAddedFlow = FALSE;
    qosFlowId = 0;

    if (qosHandle != INVALID_HANDLE_VALUE)
    {
        pfnQOSCloseHandle(qosHandle);
        qosHandle = INVALID_HANDLE_VALUE;
    }

    if (QwaveLibraryHandle != NULL) {
        pfnQOSCreateHandle = NULL;
        pfnQOSCloseHandle = NULL;
        pfnQOSAddSocketToFlow = NULL;

        FreeLibrary(QwaveLibraryHandle);
        QwaveLibraryHandle = NULL;
    }

    timeEndPeriod (1);

    WSACleanup ();
}

enet_uint32
enet_host_random_seed (void)
{
    return (enet_uint32) timeGetTime ();
}

enet_uint32
enet_time_get (void)
{
    return (enet_uint32) timeGetTime () - timeBase;
}

void
enet_time_set (enet_uint32 newTimeBase)
{
    timeBase = (enet_uint32) timeGetTime () - newTimeBase;
}

int
enet_address_set_port (ENetAddress * address, enet_uint16 port)
{
    if (address -> address.ss_family == AF_INET)
    {
        struct sockaddr_in *sin = (struct sockaddr_in *) &address -> address;
        sin -> sin_port = ENET_HOST_TO_NET_16 (port);
        return 0;
    }
    else if (address -> address.ss_family == AF_INET6)
    {
        struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *) &address -> address;
        sin6 -> sin6_port = ENET_HOST_TO_NET_16 (port);
        return 0;
    }
    else
    {
        return -1;
    }
}

int
enet_address_set_address (ENetAddress * address, struct sockaddr * addr, socklen_t addrlen)
{
    if (addrlen > sizeof(struct sockaddr_storage))
      return -1;

    memcpy (&address->address, addr, addrlen);
    address->addressLength = addrlen;
    return 0;
}

int
enet_address_equal (ENetAddress * address1, ENetAddress * address2)
{
    if (address1 -> address.ss_family != address2 -> address.ss_family)
      return 0;

    switch (address1 -> address.ss_family)
    {
    case AF_INET:
    {
        struct sockaddr_in *sin1, *sin2;
        sin1 = (struct sockaddr_in *) & address1 -> address;
        sin2 = (struct sockaddr_in *) & address2 -> address;
        return sin1 -> sin_port == sin2 -> sin_port &&
            sin1 -> sin_addr.S_un.S_addr == sin2 -> sin_addr.S_un.S_addr;
    }
    case AF_INET6:
    {
        struct sockaddr_in6 *sin6a, *sin6b;
        sin6a = (struct sockaddr_in6 *) & address1 -> address;
        sin6b = (struct sockaddr_in6 *) & address2 -> address;
        return sin6a -> sin6_port == sin6b -> sin6_port &&
            ! memcmp (& sin6a -> sin6_addr, & sin6b -> sin6_addr, sizeof (sin6a -> sin6_addr));
    }
    default:
    {
        return 0;
    }
    }
}

int
enet_address_set_host (ENetAddress * address, const char * name)
{
    struct addrinfo hints, * resultList = NULL, * result = NULL;

    memset (& hints, 0, sizeof (hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_flags = AI_ADDRCONFIG;

    if (getaddrinfo (name, NULL, & hints, & resultList) != 0)
      return -1;

    for (result = resultList; result != NULL; result = result -> ai_next)
    {
        memcpy (& address -> address, result -> ai_addr, result -> ai_addrlen);
        address -> addressLength = result -> ai_addrlen;
        
        freeaddrinfo (resultList);
        
        return 0;
    }

    if (resultList != NULL)
      freeaddrinfo (resultList);

    return -1;
}

int
enet_socket_bind (ENetSocket socket, const ENetAddress * address)
{
    return bind (socket,
        (struct sockaddr *) & address -> address,
        address -> addressLength);
}

int
enet_socket_get_address (ENetSocket socket, ENetAddress * address)
{
    address -> addressLength = sizeof (address -> address);

    if (getsockname (socket, (struct sockaddr *) & address -> address, & address -> addressLength) == -1)
      return -1;

    return 0;
}

int
enet_socket_listen (ENetSocket socket, int backlog)
{
    return listen (socket, backlog < 0 ? SOMAXCONN : backlog) == SOCKET_ERROR ? -1 : 0;
}

ENetSocket
enet_socket_create (int af, ENetSocketType type)
{
    SOCKET sock = socket (af, type == ENET_SOCKET_TYPE_DATAGRAM ? SOCK_DGRAM : SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET)
        return INVALID_SOCKET;

    DWORD bytesReturned;
    GUID wsaRecvMsgGuid = WSAID_WSARECVMSG;
    if (WSAIoctl(sock, SIO_GET_EXTENSION_FUNCTION_POINTER, &wsaRecvMsgGuid, sizeof(wsaRecvMsgGuid),
                 &pfnWSARecvMsg, sizeof(pfnWSARecvMsg), &bytesReturned, NULL, NULL) == SOCKET_ERROR) {
        closesocket(sock);
        return INVALID_SOCKET;
    }

    BOOL val;

    // Enable dual-stack operation for IPv6 sockets
    if (af == AF_INET6) {
        val = FALSE;
        if (setsockopt(sock, IPPROTO_IPV6, IPV6_V6ONLY, (char*)&val, sizeof(val)) == SOCKET_ERROR) {
            closesocket(sock);
            return INVALID_SOCKET;
        }
    }

    // Enable returning local address info for IPv4 and dual-stack sockets
    val = TRUE;
    if (setsockopt(sock, IPPROTO_IP, IP_PKTINFO, (char*)&val, sizeof(val)) == SOCKET_ERROR) {
        closesocket(sock);
        return INVALID_SOCKET;
    }

    // Enable returning local address info for IPv6 and dual-stack sockets
    if (af == AF_INET6) {
        val = TRUE;
        if (setsockopt(sock, IPPROTO_IPV6, IPV6_PKTINFO, (char*)&val, sizeof(val)) == SOCKET_ERROR) {
            closesocket(sock);
            return INVALID_SOCKET;
        }
    }

    return sock;
}

int
enet_socket_set_option (ENetSocket socket, ENetSocketOption option, int value)
{
    int result = SOCKET_ERROR;
    switch (option)
    {
        case ENET_SOCKOPT_NONBLOCK:
        {
            u_long nonBlocking = (u_long) value;
            result = ioctlsocket (socket, FIONBIO, & nonBlocking);
            break;
        }

        case ENET_SOCKOPT_REUSEADDR:
            result = setsockopt (socket, SOL_SOCKET, SO_REUSEADDR, (char *) & value, sizeof (int));
            break;

        case ENET_SOCKOPT_RCVBUF:
            result = setsockopt (socket, SOL_SOCKET, SO_RCVBUF, (char *) & value, sizeof (int));
            break;

        case ENET_SOCKOPT_SNDBUF:
            result = setsockopt (socket, SOL_SOCKET, SO_SNDBUF, (char *) & value, sizeof (int));
            break;

        case ENET_SOCKOPT_RCVTIMEO:
            result = setsockopt (socket, SOL_SOCKET, SO_RCVTIMEO, (char *) & value, sizeof (int));
            break;

        case ENET_SOCKOPT_SNDTIMEO:
            result = setsockopt (socket, SOL_SOCKET, SO_SNDTIMEO, (char *) & value, sizeof (int));
            break;

        case ENET_SOCKOPT_NODELAY:
            result = setsockopt (socket, IPPROTO_TCP, TCP_NODELAY, (char *) & value, sizeof (int));
            break;

        case ENET_SOCKOPT_QOS:
        {
            if (value)
            {
                QOS_VERSION qosVersion;

                qosVersion.MajorVersion = 1;
                qosVersion.MinorVersion = 0;
                if (pfnQOSCreateHandle == NULL || !pfnQOSCreateHandle(&qosVersion, &qosHandle))
                {
                    qosHandle = INVALID_HANDLE_VALUE;
                }
            }
            else if (qosHandle != INVALID_HANDLE_VALUE)
            {
                pfnQOSCloseHandle(qosHandle);
                qosHandle = INVALID_HANDLE_VALUE;
            }

            qosAddedFlow = FALSE;
            qosFlowId = 0;

            result = 0;
            break;
        }

        default:
            break;
    }
    return result == SOCKET_ERROR ? -1 : 0;
}

int
enet_socket_get_option (ENetSocket socket, ENetSocketOption option, int * value)
{
    int result = SOCKET_ERROR, len;
    switch (option)
    {
        case ENET_SOCKOPT_ERROR:
            len = sizeof(int);
            result = getsockopt (socket, SOL_SOCKET, SO_ERROR, (char *) value, & len);
            break;

        default:
            break;
    }
    return result == SOCKET_ERROR ? -1 : 0;
}

int
enet_socket_connect (ENetSocket socket, const ENetAddress * address)
{
    int result;

    result = connect (socket, (struct sockaddr *) & address -> address, address -> addressLength);
    if (result == SOCKET_ERROR && WSAGetLastError () != WSAEWOULDBLOCK)
      return -1;

    return 0;
}

ENetSocket
enet_socket_accept (ENetSocket socket, ENetAddress * address)
{
    int result;

    if (address != NULL)
      address -> addressLength = sizeof (address -> address);

    result = accept (socket, 
                     address != NULL ? (struct sockaddr *) & address -> address : NULL, 
                     address != NULL ? & address -> addressLength : NULL);
    
    if (result == -1)
      return ENET_SOCKET_NULL;

    return result;
}

int
enet_socket_shutdown (ENetSocket socket, ENetSocketShutdown how)
{
    return shutdown (socket, (int) how) == SOCKET_ERROR ? -1 : 0;
}

void
enet_socket_destroy (ENetSocket socket)
{
    if (socket != INVALID_SOCKET)
      closesocket (socket);
}

int
enet_socket_send (ENetSocket socket,
                  const ENetAddress * peerAddress,
                  const ENetAddress * localAddress,
                  const ENetBuffer * buffers,
                  size_t bufferCount)
{
    DWORD sentLength;
    WSAMSG msg = { 0 };
    char controlBufData[1024];

    if (!qosAddedFlow && qosHandle != INVALID_HANDLE_VALUE)
    {
        qosFlowId = 0; // Must be initialized to 0
        pfnQOSAddSocketToFlow(qosHandle,
                              socket,
                              (struct sockaddr *)&peerAddress->address,
                              QOSTrafficTypeControl,
                              QOS_NON_ADAPTIVE_FLOW,
                              &qosFlowId);

        // Even if we failed, don't try again
        qosAddedFlow = TRUE;
    }

    msg.name = peerAddress != NULL ? (struct sockaddr *) & peerAddress -> address : NULL;
    msg.namelen = peerAddress != NULL ? peerAddress -> addressLength : 0;
    msg.lpBuffers = (LPWSABUF) buffers;
    msg.dwBufferCount = (DWORD) bufferCount;

    // We always send traffic from the same local address as we last received
    // from this peer to ensure it correctly recognizes our responses as
    // coming from the expected host.
    if (localAddress != NULL) {
        if (localAddress->address.ss_family == AF_INET) {
            IN_PKTINFO pktInfo;

            pktInfo.ipi_addr = ((PSOCKADDR_IN)&localAddress->address)->sin_addr;
            pktInfo.ipi_ifindex = 0; // Unspecified

            msg.Control.buf = controlBufData;
            msg.Control.len = WSA_CMSG_SPACE(sizeof(pktInfo));

            PWSACMSGHDR chdr = WSA_CMSG_FIRSTHDR(&msg);
            chdr->cmsg_level = IPPROTO_IP;
            chdr->cmsg_type = IP_PKTINFO;
            chdr->cmsg_len = WSA_CMSG_LEN(sizeof(pktInfo));
            memcpy(WSA_CMSG_DATA(chdr), &pktInfo, sizeof(pktInfo));
        }
        else if (localAddress->address.ss_family == AF_INET6) {
            IN6_PKTINFO pktInfo;

            pktInfo.ipi6_addr = ((PSOCKADDR_IN6)&localAddress->address)->sin6_addr;
            pktInfo.ipi6_ifindex = 0; // Unspecified

            msg.Control.buf = controlBufData;
            msg.Control.len = WSA_CMSG_SPACE(sizeof(pktInfo));

            PWSACMSGHDR chdr = WSA_CMSG_FIRSTHDR(&msg);
            chdr->cmsg_level = IPPROTO_IPV6;
            chdr->cmsg_type = IPV6_PKTINFO;
            chdr->cmsg_len = WSA_CMSG_LEN(sizeof(pktInfo));
            memcpy(WSA_CMSG_DATA(chdr), &pktInfo, sizeof(pktInfo));
        }
    }

    if (WSASendMsg (socket,
                    & msg,
                    0,
                    & sentLength,
                    NULL,
                    NULL) == SOCKET_ERROR)
    {
       if (WSAGetLastError () == WSAEWOULDBLOCK)
         return 0;

       return -1;
    }

    return (int) sentLength;
}

int
enet_socket_receive (ENetSocket socket,
                     ENetAddress * peerAddress,
                     ENetAddress * localAddress,
                     ENetBuffer * buffers,
                     size_t bufferCount)
{
    DWORD recvLength;
    WSAMSG msg = { 0 };
    char controlBufData[1024];

    msg.name = peerAddress != NULL ? (struct sockaddr *) & peerAddress -> address : NULL;
    msg.namelen = peerAddress != NULL ? sizeof (peerAddress -> address) : 0;
    msg.lpBuffers = (LPWSABUF) buffers;
    msg.dwBufferCount = (DWORD) bufferCount;
    msg.Control.buf = controlBufData;
    msg.Control.len = sizeof(controlBufData);

    if (pfnWSARecvMsg (socket,
                       & msg,
                       & recvLength,
                       NULL,
                       NULL) == SOCKET_ERROR)
    {
       switch (WSAGetLastError ())
       {
       case WSAEWOULDBLOCK:
       case WSAECONNRESET:
          return 0;
       }

       return -1;
    }

    if (msg.dwFlags & MSG_PARTIAL)
      return -1;

    // Retrieve the local address that this traffic was received on
    // to ensure we respond from the correct address/interface.
    if (localAddress != NULL) {
        for (PWSACMSGHDR chdr = WSA_CMSG_FIRSTHDR(&msg); chdr != NULL; chdr = WSA_CMSG_NXTHDR(&msg, chdr)) {
            if (chdr->cmsg_level == IPPROTO_IP && chdr->cmsg_type == IP_PKTINFO) {
                PSOCKADDR_IN localAddr = (PSOCKADDR_IN)&localAddress->address;

                localAddr->sin_family = AF_INET;
                localAddr->sin_addr = ((IN_PKTINFO*)WSA_CMSG_DATA(chdr))->ipi_addr;

                localAddress->addressLength = sizeof(*localAddr);
                break;
            }
            else if (chdr->cmsg_level == IPPROTO_IPV6 && chdr->cmsg_type == IPV6_PKTINFO) {
                PSOCKADDR_IN6 localAddr = (PSOCKADDR_IN6)&localAddress->address;

                localAddr->sin6_family = AF_INET6;
                localAddr->sin6_addr = ((IN6_PKTINFO*)WSA_CMSG_DATA(chdr))->ipi6_addr;

                localAddress->addressLength = sizeof(*localAddr);
                break;
            }
        }
    }

    peerAddress->addressLength = msg.namelen;
    return (int) recvLength;
}

int
enet_socketset_select (ENetSocket maxSocket, ENetSocketSet * readSet, ENetSocketSet * writeSet, enet_uint32 timeout)
{
    struct timeval timeVal;

    timeVal.tv_sec = timeout / 1000;
    timeVal.tv_usec = (timeout % 1000) * 1000;

    return select (maxSocket + 1, readSet, writeSet, NULL, & timeVal);
}

int
enet_socket_wait (ENetSocket socket, enet_uint32 * condition, enet_uint32 timeout)
{
    fd_set readSet, writeSet;
    struct timeval timeVal;
    int selectCount;
    
    timeVal.tv_sec = timeout / 1000;
    timeVal.tv_usec = (timeout % 1000) * 1000;
    
    FD_ZERO (& readSet);
    FD_ZERO (& writeSet);

    if (* condition & ENET_SOCKET_WAIT_SEND)
      FD_SET (socket, & writeSet);

    if (* condition & ENET_SOCKET_WAIT_RECEIVE)
      FD_SET (socket, & readSet);

    selectCount = select (socket + 1, & readSet, & writeSet, NULL, & timeVal);

    if (selectCount < 0)
      return -1;

    * condition = ENET_SOCKET_WAIT_NONE;

    if (selectCount == 0)
      return 0;

    if (FD_ISSET (socket, & writeSet))
      * condition |= ENET_SOCKET_WAIT_SEND;
    
    if (FD_ISSET (socket, & readSet))
      * condition |= ENET_SOCKET_WAIT_RECEIVE;

    return 0;
} 

#endif

