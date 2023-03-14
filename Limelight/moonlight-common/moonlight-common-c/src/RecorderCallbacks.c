#include "Limelight-internal.h"

static FILE* videoFile;
static FILE* audioFile;

static DECODER_RENDERER_CALLBACKS realDrCallbacks;
static AUDIO_RENDERER_CALLBACKS realArCallbacks;

static int recDrSetup(int videoFormat, int width, int height, int redrawRate, void* context, int drFlags)
{
    const char* path = context;
    
    if (path != NULL) {
        videoFile = fopen(path, "wb");
        if (videoFile == NULL) {
            return -1;
        }
    }
    else {
        Limelog("Video recording will not be enabled - file path not specified in drContext!\n");
    }

    return realDrCallbacks.setup(videoFormat, width, height, redrawRate, NULL, drFlags);
}

static void recDrCleanup(void)
{
    if (videoFile != NULL) {
        fclose(videoFile);
        videoFile = NULL;
    }

    realDrCallbacks.cleanup();
}

static int recDrSubmitDecodeUnit(PDECODE_UNIT decodeUnit)
{
    if (videoFile != NULL) {
        PLENTRY entry = decodeUnit->bufferList;
        while (entry != NULL) {
            fwrite(entry->data, 1, entry->length, videoFile);
            entry = entry->next;
        }
    }

    return realDrCallbacks.submitDecodeUnit(decodeUnit);
}

static int recArInit(int audioConfiguration, POPUS_MULTISTREAM_CONFIGURATION opusConfig, void* context, int arFlags)
{
    const char* path = context;

    if (path != NULL) {
        audioFile = fopen(path, "wb");
        if (audioFile == NULL) {
            return -1;
        }
    }
    else {
        Limelog("Audio recording will not be enabled - file path not specified in arContext!\n");
    }

    return realArCallbacks.init(audioConfiguration, opusConfig, NULL, arFlags);
}

static void recArCleanup(void)
{
    if (audioFile != NULL) {
        fclose(audioFile);
        audioFile = NULL;
    }

    realArCallbacks.cleanup();
}

static void recArDecodeAndPlaySample(char* sampleData, int sampleLength)
{
    if (audioFile != NULL) {
        fwrite(sampleData, 1, sampleLength, audioFile);
    }

    realArCallbacks.decodeAndPlaySample(sampleData, sampleLength);
}

void setRecorderCallbacks(PDECODER_RENDERER_CALLBACKS drCallbacks, PAUDIO_RENDERER_CALLBACKS arCallbacks)
{
    realDrCallbacks = *drCallbacks;
    realArCallbacks = *arCallbacks;

    drCallbacks->setup = recDrSetup;
    drCallbacks->cleanup = recDrCleanup;
    drCallbacks->submitDecodeUnit = recDrSubmitDecodeUnit;

    arCallbacks->init = recArInit;
    arCallbacks->cleanup = recArCleanup;
    arCallbacks->decodeAndPlaySample = recArDecodeAndPlaySample;
}
