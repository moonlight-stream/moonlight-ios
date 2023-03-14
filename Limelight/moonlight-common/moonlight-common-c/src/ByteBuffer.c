#include "ByteBuffer.h"

void BbInitializeWrappedBuffer(PBYTE_BUFFER buff, char* data, int offset, int length, int byteOrder) {
    buff->buffer = data + offset;
    buff->length = length;
    buff->position = 0;
    buff->byteOrder = byteOrder;
}

// Get the long long in the correct byte order
static uint64_t byteSwap64(PBYTE_BUFFER buff, uint64_t l) {
    if (buff->byteOrder == BYTE_ORDER_BIG) {
        return BE64(l);
    }
    else {
        return LE64(l);
    }
}

// Get the int in the correct byte order
static uint32_t byteSwap32(PBYTE_BUFFER buff, uint32_t i) {
    if (buff->byteOrder == BYTE_ORDER_BIG) {
        return BE32(i);
    }
    else {
        return LE32(i);
    }
}

// Get the short in the correct byte order
static uint16_t byteSwap16(PBYTE_BUFFER buff, uint16_t s) {
    if (buff->byteOrder == BYTE_ORDER_BIG) {
        return BE16(s);
    }
    else {
        return LE16(s);
    }
}

bool BbAdvanceBuffer(PBYTE_BUFFER buff, int offset) {
    if (buff->position + offset > buff->length) {
        return false;
    }

    buff->position += offset;

    return true;
}

// Get a byte from the byte buffer
bool BbGet8(PBYTE_BUFFER buff, uint8_t* c) {
    if (buff->position + sizeof(*c) > buff->length) {
        return false;
    }

    memcpy(c, &buff->buffer[buff->position], sizeof(*c));
    buff->position += sizeof(*c);

    return true;
}

// Get a short from the byte buffer
bool BbGet16(PBYTE_BUFFER buff, uint16_t* s) {
    if (buff->position + sizeof(*s) > buff->length) {
        return false;
    }

    memcpy(s, &buff->buffer[buff->position], sizeof(*s));
    buff->position += sizeof(*s);

    *s = byteSwap16(buff, *s);

    return true;
}

// Get an int from the byte buffer
bool BbGet32(PBYTE_BUFFER buff, uint32_t* i) {
    if (buff->position + sizeof(*i) > buff->length) {
        return false;
    }

    memcpy(i, &buff->buffer[buff->position], sizeof(*i));
    buff->position += sizeof(*i);

    *i = byteSwap32(buff, *i);

    return true;
}

// Get a long from the byte buffer
bool BbGet64(PBYTE_BUFFER buff, uint64_t* l) {
    if (buff->position + sizeof(*l) > buff->length) {
        return false;
    }

    memcpy(l, &buff->buffer[buff->position], sizeof(*l));
    buff->position += sizeof(*l);

    *l = byteSwap64(buff, *l);

    return true;
}

// Put an int into the byte buffer
bool BbPut32(PBYTE_BUFFER buff, uint32_t i) {
    if (buff->position + sizeof(i) > buff->length) {
        return false;
    }

    i = byteSwap32(buff, i);

    memcpy(&buff->buffer[buff->position], &i, sizeof(i));
    buff->position += sizeof(i);

    return true;
}

// Put a long into the byte buffer
bool BbPut64(PBYTE_BUFFER buff, uint64_t l) {
    if (buff->position + sizeof(l) > buff->length) {
        return false;
    }

    l = byteSwap64(buff, l);

    memcpy(&buff->buffer[buff->position], &l, sizeof(l));
    buff->position += sizeof(l);

    return true;
}

// Put a short into the byte buffer
bool BbPut16(PBYTE_BUFFER buff, uint16_t s) {
    if (buff->position + sizeof(s) > buff->length) {
        return false;
    }

    s = byteSwap16(buff, s);

    memcpy(&buff->buffer[buff->position], &s, sizeof(s));
    buff->position += sizeof(s);

    return true;
}

// Put a byte into the buffer
bool BbPut8(PBYTE_BUFFER buff, uint8_t c) {
    if (buff->position + sizeof(c) > buff->length) {
        return false;
    }

    memcpy(&buff->buffer[buff->position], &c, sizeof(c));
    buff->position += sizeof(c);

    return true;
}
