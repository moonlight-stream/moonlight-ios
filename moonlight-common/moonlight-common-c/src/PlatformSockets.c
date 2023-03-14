#include "Limelight-internal.h"

#define TEST_PORT_TIMEOUT_SEC 3

#define RCV_BUFFER_SIZE_MIN  32767
#define RCV_BUFFER_SIZE_STEP 16384

#if defined(__vita__)
#define TCPv4_MSS 512
#else
#define TCPv4_MSS 536
#endif
#define TCPv6_MSS 1220

#if defined(LC_WINDOWS)

#ifndef SIO_UDP_CONNRESET
#define SIO_UDP_CONNRESET _WSAIOW(IOC_VENDOR, 12)
#endif

static HMODULE WlanApiLibraryHandle;
static HANDLE WlanHandle;

DWORD (WINAPI *pfnWlanOpenHandle)(DWORD dwClientVersion, PVOID pReserved, PDWORD pdwNegotiatedVersion, PHANDLE phClientHandle);
DWORD (WINAPI *pfnWlanCloseHandle)(HANDLE hClientHandle, PVOID pReserved);
DWORD (WINAPI *pfnWlanEnumInterfaces)(HANDLE hClientHandle, PVOID pReserved, PWLAN_INTERFACE_INFO_LIST *ppInterfaceList);
VOID (WINAPI *pfnWlanFreeMemory)(PVOID pMemory);
DWORD (WINAPI *pfnWlanSetInterface)(HANDLE hClientHandle, CONST GUID *pInterfaceGuid, WLAN_INTF_OPCODE OpCode, DWORD dwDataSize, CONST PVOID pData, PVOID pReserved);

#ifndef WLAN_API_MAKE_VERSION
#define WLAN_API_MAKE_VERSION(_major, _minor)   (((DWORD)(_minor)) << 16 | (_major))
#endif

#endif

void addrToUrlSafeString(struct sockaddr_storage* addr, char* string)
{
    char addrstr[URLSAFESTRING_LEN];

#ifdef AF_INET6
    if (addr->ss_family == AF_INET6) {
        struct sockaddr_in6* sin6 = (struct sockaddr_in6*)addr;
        inet_ntop(addr->ss_family, &sin6->sin6_addr, addrstr, sizeof(addrstr));

        // IPv6 addresses need to be enclosed in brackets for URLs
        sprintf(string, "[%s]", addrstr);
    }
    else
#endif
    {
        struct sockaddr_in* sin = (struct sockaddr_in*)addr;
        inet_ntop(addr->ss_family, &sin->sin_addr, addrstr, sizeof(addrstr));

        // IPv4 addresses are returned without changes
        sprintf(string, "%s", addrstr);
    }
}

void shutdownTcpSocket(SOCKET s) {
    // Calling shutdown() prior to close wakes up callers
    // blocked in connect(), recv(), and friends.
    shutdown(s, SHUT_RDWR);
}

int setNonFatalRecvTimeoutMs(SOCKET s, int timeoutMs) {
#if defined(LC_WINDOWS)
    // Windows says that SO_RCVTIMEO puts the socket into an indeterminate state
    // when a timeout occurs. MSDN doesn't go into it any more than that, but it
    // seems likely that they are referring to the inability to know whether a
    // cancelled request consumed some data or not (very relevant for stream-based
    // protocols like TCP). Since our sockets are UDP which is already unreliable,
    // losing some data in a very rare case is fine, especially because we get to
    // halve the number of syscalls per packet by avoiding select().
    return setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeoutMs, sizeof(timeoutMs));
#elif defined(__WIIU__)
    // timeouts aren't supported on Wii U
    return -1;
#else
    struct timeval val;

    val.tv_sec = 0;
    val.tv_usec = timeoutMs * 1000;

    return setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, (char*)&val, sizeof(val));
#endif
}

int pollSockets(struct pollfd* pollFds, int pollFdsCount, int timeoutMs) {
#if defined(LC_WINDOWS)
    // We could have used WSAPoll() but it has some nasty bugs
    // https://daniel.haxx.se/blog/2012/10/10/wsapoll-is-broken/
    //
    // We'll emulate WSAPoll() with select(). Fortunately, Microsoft's definition
    // of fd_set does not have the same stack corruption hazards that UNIX does.
    fd_set readFds, writeFds, exceptFds;
    int i, err, nfds;
    struct timeval tv;

    FD_ZERO(&readFds);
    FD_ZERO(&writeFds);
    FD_ZERO(&exceptFds);

    nfds = 0;
    for (i = 0; i < pollFdsCount; i++) {
        // Clear revents on input like poll() does
        pollFds[i].revents = 0;

        if (pollFds[i].events & POLLIN) {
            FD_SET(pollFds[i].fd, &readFds);
        }
        if (pollFds[i].events & POLLOUT) {
            FD_SET(pollFds[i].fd, &writeFds);

            // Windows signals failed connections as an exception,
            // while Linux signals them as writeable.
            FD_SET(pollFds[i].fd, &exceptFds);
        }
    }

    tv.tv_sec = timeoutMs / 1000;
    tv.tv_usec = (timeoutMs % 1000) * 1000;

    err = select(nfds, &readFds, &writeFds, &exceptFds, timeoutMs >= 0 ? &tv : NULL);
    if (err <= 0) {
        // Error or timeout
        return err;
    }

    for (i = 0; i < pollFdsCount; i++) {
        if (FD_ISSET(pollFds[i].fd, &readFds)) {
            pollFds[i].revents |= POLLRDNORM;
        }

        if (FD_ISSET(pollFds[i].fd, &writeFds)) {
            pollFds[i].revents |= POLLWRNORM;
        }

        if (FD_ISSET(pollFds[i].fd, &exceptFds)) {
            pollFds[i].revents |= POLLERR;
        }
    }

    return err;
#else
    return poll(pollFds, pollFdsCount, timeoutMs);
#endif
}

bool isSocketReadable(SOCKET s) {
    struct pollfd pfd;
    int err;

    pfd.fd = s;
    pfd.events = POLLIN;
    err = pollSockets(&pfd, 1, 0);
    if (err <= 0) {
        return false;
    }

    return true;
}

int recvUdpSocket(SOCKET s, char* buffer, int size, bool useSelect) {
    int err;
    
    do {
        if (useSelect) {
            struct pollfd pfd;

            // Wait up to 100 ms for the socket to be readable
            pfd.fd = s;
            pfd.events = POLLIN;
            err = pollSockets(&pfd, 1, UDP_RECV_POLL_TIMEOUT_MS);
            if (err <= 0) {
                // Return if an error or timeout occurs
                return err;
            }

            // This won't block since the socket is readable
            err = (int)recvfrom(s, buffer, size, 0, NULL, NULL);
        }
        else {
            // The caller has already configured a timeout on this
            // socket via SO_RCVTIMEO, so we can avoid a syscall
            // for each packet.
            err = (int)recvfrom(s, buffer, size, 0, NULL, NULL);
            if (err < 0 &&
                    (LastSocketError() == EWOULDBLOCK ||
                     LastSocketError() == EINTR ||
                     LastSocketError() == EAGAIN ||
         #if defined(LC_WINDOWS)
                     // This error is specific to overlapped I/O which isn't even
                     // possible to perform with recvfrom(). It seems to randomly
                     // be returned instead of WSAETIMEDOUT on certain systems.
                     LastSocketError() == WSA_IO_PENDING ||
         #endif
                     LastSocketError() == ETIMEDOUT)) {
                // Return 0 for timeout
                return 0;
            }
        }

    // We may receive an error due to a previous ICMP Port Unreachable error received
    // by this socket. We want to ignore those and continue reading. If the remote party
    // is really dead, ENet or TCP connection failures will trigger connection teardown.
#if defined(LC_WINDOWS)
    } while (err < 0 && LastSocketError() == WSAECONNRESET);
#else
    } while (err < 0 && LastSocketError() == ECONNREFUSED);
#endif

    return err;
}

void closeSocket(SOCKET s) {
#if defined(LC_WINDOWS)
    closesocket(s);
#else
    close(s);
#endif
}

SOCKET bindUdpSocket(int addrfamily, int bufferSize) {
    SOCKET s;
    struct sockaddr_storage addr;
    int err;
    SOCKADDR_LEN addrLen;

#ifdef AF_INET6
    LC_ASSERT(addrfamily == AF_INET || addrfamily == AF_INET6);
    addrLen = (addrfamily == AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6));
#else
    LC_ASSERT(addrfamily == AF_INET);
    addrLen = sizeof(struct sockaddr_in);
#endif

    s = createSocket(addrfamily, SOCK_DGRAM, IPPROTO_UDP, false);
    if (s == INVALID_SOCKET) {
        return INVALID_SOCKET;
    }

    memset(&addr, 0, sizeof(addr));
    addr.ss_family = addrfamily;
    if (bind(s, (struct sockaddr*) &addr, addrLen) == SOCKET_ERROR) {
        err = LastSocketError();
        Limelog("bind() failed: %d\n", err);
        closeSocket(s);
        SetLastSocketError(err);
        return INVALID_SOCKET;
    }

#if defined(LC_DARWIN)
    {
        // Disable SIGPIPE on iOS
        int val = 1;
        setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, (char*)&val, sizeof(val));
    }
#elif defined(LC_WINDOWS)
    {
        // Disable WSAECONNRESET for UDP sockets on Windows
        BOOL val = FALSE;
        DWORD bytesReturned = 0;
        if (WSAIoctl(s, SIO_UDP_CONNRESET, &val, sizeof(val), NULL, 0, &bytesReturned, NULL, NULL) != 0) {
            Limelog("WSAIoctl(SIO_UDP_CONNRESET) failed: %d\n", LastSocketError());
        }
    }
#endif

    // We start at the requested recv buffer value and step down until we find
    // a value that the OS will accept.
    for (;;) {
        err = setsockopt(s, SOL_SOCKET, SO_RCVBUF, (char*)&bufferSize, sizeof(bufferSize));
        if (err == 0) {
            // Successfully set a buffer size
            break;
        }
        else if (bufferSize <= RCV_BUFFER_SIZE_MIN) {
            // Failed to set a buffer size within the allowable range
            break;
        }
        else if (bufferSize - RCV_BUFFER_SIZE_STEP <= RCV_BUFFER_SIZE_MIN) {
            // Last shot - we're trying the minimum
            bufferSize = RCV_BUFFER_SIZE_MIN;
        }
        else {
            // Lower the requested size by another step
            bufferSize -= RCV_BUFFER_SIZE_STEP;
        }
    }
    
#if defined(LC_DEBUG)
    if (err == 0) {
        Limelog("Selected receive buffer size: %d\n", bufferSize);
    }
    else {
        Limelog("Unable to set receive buffer size: %d\n", LastSocketError());
    }
#endif

    return s;
}

int setSocketNonBlocking(SOCKET s, bool enabled) {
#if defined(__vita__)
    int val = enabled ? 1 : 0;
    return setsockopt(s, SOL_SOCKET, SO_NONBLOCK, (char*)&val, sizeof(val));
#elif defined(O_NONBLOCK)
    return fcntl(s, F_SETFL, (enabled ? O_NONBLOCK : 0) | (fcntl(s, F_GETFL) & ~O_NONBLOCK));
#elif defined(FIONBIO)
#ifdef LC_WINDOWS
    u_long val = enabled ? 1 : 0;
#else
    int val = enabled ? 1 : 0;
#endif
    return ioctlsocket(s, FIONBIO, &val);
#else
#error Please define your platform non-blocking sockets API!
#endif
}

SOCKET createSocket(int addressFamily, int socketType, int protocol, bool nonBlocking) {
    SOCKET s;

    s = socket(addressFamily, socketType, protocol);
    if (s == INVALID_SOCKET) {
        Limelog("socket() failed: %d\n", (int)LastSocketError());
        return INVALID_SOCKET;
    }

#ifdef LC_DARWIN
    {
        // Disable SIGPIPE on iOS
        int val = 1;
        setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, (char*)&val, sizeof(val));
    }
#endif

    if (nonBlocking) {
        setSocketNonBlocking(s, true);
    }

    return s;
}

SOCKET connectTcpSocket(struct sockaddr_storage* dstaddr, SOCKADDR_LEN addrlen, unsigned short port, int timeoutSec) {
    SOCKET s;
    LC_SOCKADDR addr;
    struct pollfd pfd;
    int err;
    int val;

    // Create a non-blocking TCP socket
    s = createSocket(dstaddr->ss_family, SOCK_STREAM, IPPROTO_TCP, true);
    if (s == INVALID_SOCKET) {
        return INVALID_SOCKET;
    }

    // Some broken routers/firewalls (or routes with multiple broken routers) may result in TCP packets
    // being dropped without without us receiving an ICMP Fragmentation Needed packet. For example,
    // a router can elect to drop rather than fragment even without DF set. A misconfigured firewall
    // or router on the path back to us may block the ICMP Fragmentation Needed packet required for
    // PMTUD to work and thus we end up with a black hole route. Some OSes recover from this better
    // than others, but we can avoid the issue altogether by capping our MSS to the value mandated
    // by RFC 879 and RFC 2460.
    //
    // Note: This only changes the max packet size we can *receive* from the host PC.
    // We still must split our own sends into smaller chunks with TCP_NODELAY enabled to
    // avoid MTU issues on the way out to to the target.
#if defined(LC_WINDOWS)
    // Windows doesn't support setting TCP_MAXSEG but IP_PMTUDISC_DONT forces the MSS to the protocol
    // minimum which is what we want here. Linux doesn't do this (disabling PMTUD just avoids setting DF).
    if (dstaddr->ss_family == AF_INET) {
        val = IP_PMTUDISC_DONT;
        if (setsockopt(s, IPPROTO_IP, IP_MTU_DISCOVER, (char*)&val, sizeof(val)) < 0) {
            Limelog("setsockopt(IP_MTU_DISCOVER, IP_PMTUDISC_DONT) failed: %d\n", val, (int)LastSocketError());
        }
    }
    else {
        val = IP_PMTUDISC_DONT;
        if (setsockopt(s, IPPROTO_IPV6, IPV6_MTU_DISCOVER, (char*)&val, sizeof(val)) < 0) {
            Limelog("setsockopt(IPV6_MTU_DISCOVER, IP_PMTUDISC_DONT) failed: %d\n", val, (int)LastSocketError());
        }
    }
#elif defined(TCP_NOOPT)
    // On BSD-based OSes (including macOS/iOS), TCP_NOOPT seems to be the only way to
    // restrict MSS to the minimum. It strips all options out of the SYN packet which
    // forces the remote party to fall back to the minimum MSS. TCP_MAXSEG doesn't seem
    // to work correctly for outbound connections on macOS/iOS.
    val = 1;
    if (setsockopt(s, IPPROTO_TCP, TCP_NOOPT, (char*)&val, sizeof(val)) < 0) {
        Limelog("setsockopt(TCP_NOOPT, %d) failed: %d\n", val, (int)LastSocketError());
    }
#elif defined(TCP_MAXSEG)
    val = dstaddr->ss_family == AF_INET ? TCPv4_MSS : TCPv6_MSS;
    if (setsockopt(s, IPPROTO_TCP, TCP_MAXSEG, (char*)&val, sizeof(val)) < 0) {
        Limelog("setsockopt(TCP_MAXSEG, %d) failed: %d\n", val, (int)LastSocketError());
    }
#endif

    // Start connection
    memcpy(&addr, dstaddr, addrlen);
    SET_PORT(&addr, port);
    err = connect(s, (struct sockaddr*) &addr, addrlen);
    if (err < 0) {
        err = (int)LastSocketError();
        if (err != EWOULDBLOCK && err != EAGAIN && err != EINPROGRESS) {
            goto Exit;
        }
    }
    
    // Wait for the connection to complete or the timeout to elapse
    pfd.fd = s;
    pfd.events = POLLOUT;
    err = pollSockets(&pfd, 1, timeoutSec * 1000);
    if (err < 0) {
        // pollSockets() failed
        err = LastSocketError();
        Limelog("pollSockets() failed: %d\n", err);
        closeSocket(s);
        SetLastSocketError(err);
        return INVALID_SOCKET;
    }
    else if (err == 0) {
        // pollSockets() timed out
        Limelog("Connection timed out after %d seconds (TCP port %u)\n", timeoutSec, port);
        closeSocket(s);
        SetLastSocketError(ETIMEDOUT);
        return INVALID_SOCKET;
    }
    else {
        // The socket was signalled
        SOCKADDR_LEN len = sizeof(err);
        getsockopt(s, SOL_SOCKET, SO_ERROR, (char*)&err, &len);
        if (err != 0 || (pfd.revents & POLLERR)) {
            // Get the error code
            err = (err != 0) ? err : LastSocketFail();
        }
    }

    // Disable non-blocking I/O now that the connection is established
    setSocketNonBlocking(s, false);
    
Exit:
    if (err != 0) {
        Limelog("connect() failed: %d\n", err);
        closeSocket(s);
        SetLastSocketError(err);
        return INVALID_SOCKET;
    }

    return s;
}

// See TCP_MAXSEG note in connectTcpSocket() above for more information.
// TCP_NODELAY must be enabled on the socket for this function to work!
int sendMtuSafe(SOCKET s, char* buffer, int size) {
    int bytesSent = 0;

    while (bytesSent < size) {
        int bytesToSend = size - bytesSent > TCPv4_MSS ?
                          TCPv4_MSS : size - bytesSent;

        if (send(s, &buffer[bytesSent], bytesToSend, 0) < 0) {
            return -1;
        }

        bytesSent += bytesToSend;
    }

    return bytesSent;
}

int enableNoDelay(SOCKET s) {
    int err;
    int val;

    val = 1;
    err = setsockopt(s, IPPROTO_TCP, TCP_NODELAY, (char*)&val, sizeof(val));
    if (err == SOCKET_ERROR) {
        return LastSocketError();
    }

    return 0;
}

int resolveHostName(const char* host, int family, int tcpTestPort, struct sockaddr_storage* addr, SOCKADDR_LEN* addrLen)
{
    struct addrinfo hints, *res, *currentAddr;
    int err;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = family;
    hints.ai_flags = AI_ADDRCONFIG;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    err = getaddrinfo(host, NULL, &hints, &res);
    if (err != 0) {
        Limelog("getaddrinfo(%s) failed: %d\n", host, err);
        return err;
    }
    else if (res == NULL) {
        Limelog("getaddrinfo(%s) returned success without addresses\n", host);
        return -1;
    }
    
    for (currentAddr = res; currentAddr != NULL; currentAddr = currentAddr->ai_next) {
        // Use the test port to ensure this address is working if:
        // a) We have multiple addresses
        // b) The caller asked us to test even with a single address
        if (tcpTestPort != 0 && (res->ai_next != NULL || (tcpTestPort & TCP_PORT_FLAG_ALWAYS_TEST))) {
            SOCKET testSocket = connectTcpSocket((struct sockaddr_storage*)currentAddr->ai_addr,
                                                 (SOCKADDR_LEN)currentAddr->ai_addrlen,
                                                 tcpTestPort & TCP_PORT_MASK,
                                                 TEST_PORT_TIMEOUT_SEC);
            if (testSocket == INVALID_SOCKET) {
                // Try the next address
                continue;
            }
            else {
                closeSocket(testSocket);
            }
        }
        
        memcpy(addr, currentAddr->ai_addr, currentAddr->ai_addrlen);
        *addrLen = (SOCKADDR_LEN)currentAddr->ai_addrlen;
        
        freeaddrinfo(res);
        return 0;
    }

    Limelog("No working addresses found for host: %s\n", host);
    freeaddrinfo(res);
    return -1;
}

#ifdef AF_INET6
bool isInSubnetV6(struct sockaddr_in6* sin6, unsigned char* subnet, int prefixLength) {
    int i;
    
    for (i = 0; i < prefixLength; i++) {
        unsigned char mask = 1 << (i % 8);
        if ((sin6->sin6_addr.s6_addr[i / 8] & mask) != (subnet[i / 8] & mask)) {
            return false;
        }
    }
    
    return true;
}
#endif

bool isPrivateNetworkAddress(struct sockaddr_storage* address) {

    // We only count IPv4 addresses as possibly private for now
    if (address->ss_family == AF_INET) {
        unsigned int addr;

        memcpy(&addr, &((struct sockaddr_in*)address)->sin_addr, sizeof(addr));
        addr = htonl(addr);
        
        // 10.0.0.0/8
        if ((addr & 0xFF000000) == 0x0A000000) {
            return true;
        }
        // 172.16.0.0/12
        else if ((addr & 0xFFF00000) == 0xAC100000) {
            return true;
        }
        // 192.168.0.0/16
        else if ((addr & 0xFFFF0000) == 0xC0A80000) {
            return true;
        }
        // 169.254.0.0/16
        else if ((addr & 0xFFFF0000) == 0xA9FE0000) {
            return true;
        }
    }
#ifdef AF_INET6
    else if (address->ss_family == AF_INET6) {
        struct sockaddr_in6* sin6 = (struct sockaddr_in6*)address;
        static unsigned char linkLocalPrefix[] = {0xfe, 0x80};
        static unsigned char siteLocalPrefix[] = {0xfe, 0xc0};
        static unsigned char uniqueLocalPrefix[] = {0xfc, 0x00};

        // fe80::/10
        if (isInSubnetV6(sin6, linkLocalPrefix, 10)) {
            return true;
        }
        // fec0::/10
        else if (isInSubnetV6(sin6, siteLocalPrefix, 10)) {
            return true;
        }
        // fc00::/7
        else if (isInSubnetV6(sin6, uniqueLocalPrefix, 7)) {
            return true;
        }
    }
#endif

    return false;
}

// Enable platform-specific low latency options (best-effort)
void enterLowLatencyMode(void) {
#if defined(LC_WINDOWS)
    DWORD negotiatedVersion;
    PWLAN_INTERFACE_INFO_LIST wlanInterfaceList;
    DWORD i;

    // Reduce timer period to increase wait precision
    timeBeginPeriod(1);

    // Load wlanapi.dll dynamically because it will not always be present on Windows Server SKUs.
    WlanApiLibraryHandle = LoadLibraryA("wlanapi.dll");
    if (WlanApiLibraryHandle == NULL) {
        Limelog("WLANAPI is not supported on this OS\n");
        return;
    }

    pfnWlanOpenHandle = (void*)GetProcAddress(WlanApiLibraryHandle, "WlanOpenHandle");
    pfnWlanCloseHandle = (void*)GetProcAddress(WlanApiLibraryHandle, "WlanCloseHandle");
    pfnWlanFreeMemory = (void*)GetProcAddress(WlanApiLibraryHandle, "WlanFreeMemory");
    pfnWlanEnumInterfaces = (void*)GetProcAddress(WlanApiLibraryHandle, "WlanEnumInterfaces");
    pfnWlanSetInterface = (void*)GetProcAddress(WlanApiLibraryHandle, "WlanSetInterface");

    if (pfnWlanOpenHandle == NULL || pfnWlanCloseHandle == NULL ||
            pfnWlanFreeMemory == NULL || pfnWlanEnumInterfaces == NULL || pfnWlanSetInterface == NULL) {
        LC_ASSERT(pfnWlanOpenHandle != NULL);
        LC_ASSERT(pfnWlanCloseHandle != NULL);
        LC_ASSERT(pfnWlanFreeMemory != NULL);
        LC_ASSERT(pfnWlanEnumInterfaces != NULL);
        LC_ASSERT(pfnWlanSetInterface != NULL);

        // This should never happen since that would mean Microsoft removed a public API, but
        // we'll check and fail gracefully just in case.
        FreeLibrary(WlanApiLibraryHandle);
        WlanApiLibraryHandle = NULL;
        return;
    }

    // Use the Vista+ WLAN API version
    LC_ASSERT(WlanHandle == NULL);
    if (pfnWlanOpenHandle(WLAN_API_MAKE_VERSION(2, 0), NULL, &negotiatedVersion, &WlanHandle) != ERROR_SUCCESS) {
        WlanHandle = NULL;
        return;
    }

    if (pfnWlanEnumInterfaces(WlanHandle, NULL, &wlanInterfaceList) != ERROR_SUCCESS) {
        pfnWlanCloseHandle(WlanHandle, NULL);
        WlanHandle = NULL;
        return;
    }

    for (i = 0; i < wlanInterfaceList->dwNumberOfItems; i++) {
        if (wlanInterfaceList->InterfaceInfo[i].isState == wlan_interface_state_connected) {
            DWORD error;
            BOOL value;

            // Enable media streaming mode for 802.11 wireless interfaces to reduce latency and
            // unneccessary background scanning operations that cause packet loss and jitter.
            //
            // https://docs.microsoft.com/en-us/windows-hardware/drivers/network/oid-wdi-set-connection-quality
            // https://docs.microsoft.com/en-us/previous-versions/windows/hardware/wireless/native-802-11-media-streaming
            value = TRUE;
            error = pfnWlanSetInterface(WlanHandle, &wlanInterfaceList->InterfaceInfo[i].InterfaceGuid,
                                        wlan_intf_opcode_media_streaming_mode, sizeof(value), &value, NULL);
            if (error == ERROR_SUCCESS) {
                Limelog("WLAN interface %d is now in low latency mode\n", i);
            }
        }
    }

    pfnWlanFreeMemory(wlanInterfaceList);
#else
#endif
}

void exitLowLatencyMode(void) {
#if defined(LC_WINDOWS)
    // Closing our WLAN client handle will undo our optimizations
    if (WlanHandle != NULL) {
        pfnWlanCloseHandle(WlanHandle, NULL);
        WlanHandle = NULL;
    }

    // Release the library reference to wlanapi.dll
    if (WlanApiLibraryHandle != NULL) {
        pfnWlanOpenHandle = NULL;
        pfnWlanCloseHandle = NULL;
        pfnWlanFreeMemory = NULL;
        pfnWlanEnumInterfaces = NULL;
        pfnWlanSetInterface = NULL;

        FreeLibrary(WlanApiLibraryHandle);
        WlanApiLibraryHandle = NULL;
    }

    // Restore original timer period
    timeEndPeriod(1);
#else
#endif
}

int initializePlatformSockets(void) {
#if defined(LC_WINDOWS)
    WSADATA data;
    return WSAStartup(MAKEWORD(2, 0), &data);
#elif defined(__vita__) || defined(__WIIU__)
    return 0; // already initialized
#elif defined(LC_POSIX) && !defined(LC_CHROME)
    // Disable SIGPIPE signals to avoid us getting
    // killed when a socket gets an EPIPE error
    struct sigaction sa;
    sigemptyset(&sa.sa_mask);
    sa.sa_handler = SIG_IGN;
    sa.sa_flags = 0;
    if (sigaction(SIGPIPE, &sa, 0) == -1) {
        perror("sigaction");
        return -1;
    }
    return 0;
#else
    return 0;
#endif
}

void cleanupPlatformSockets(void) {
#if defined(LC_WINDOWS)
    WSACleanup();
#else
#endif
}
