// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiBridge.h
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Bridging header for importing libchiaki C types into Swift

#ifndef ChiakiBridge_h
#define ChiakiBridge_h

// Core libchiaki headers
#include <chiaki/common.h>
#include <chiaki/log.h>
#include <chiaki/session.h>
#include <chiaki/discovery.h>
#include <chiaki/discoveryservice.h>
#include <chiaki/regist.h>
#include <chiaki/controller.h>
#include <chiaki/audio.h>
#include <chiaki/audioreceiver.h>
#include <chiaki/video.h>
#include <chiaki/videoreceiver.h>
#include <chiaki/opusdecoder.h>
#include <chiaki/opusencoder.h>
#include <chiaki/feedback.h>
#include <chiaki/feedbacksender.h>

// Remote/PSN features
#include <chiaki/remote/holepunch.h>
#include <chiaki/remote/rudp.h>

#endif /* ChiakiBridge_h */
