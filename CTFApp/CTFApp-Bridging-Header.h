//  CTFApp-Bridging-Header.h
//  All ObjC headers exposed to Swift.
//  Set in Build Settings → Swift Compiler → Objective-C Bridging Header

#ifndef CTFApp_Bridging_Header_h
#define CTFApp_Bridging_Header_h

// SQLite — for S3 (StorageChallengeSetup)
#import <sqlite3.h>

// dyld image enumeration — for JailbreakDetector.swift (B4 target)
// Exposes: _dyld_image_count(), _dyld_get_image_name()
#import <mach-o/dyld.h>

// Binary challenge targets
#import "VulnModules/Binary/CTFFlagStore.h"
#import "VulnModules/Binary/CTFAntiDebug.h"
#import "VulnModules/Binary/CTFVault.h"
#import "VulnModules/Binary/CTFPart1.h"
#import "VulnModules/Binary/CTFPart2.h"
#import "VulnModules/Binary/CTFPart3.h"
#import "VulnModules/Binary/CTFJailbreakDetectorAdvanced.h"
#import "VulnModules/Binary/CTFMemoryVault.h"

#endif
