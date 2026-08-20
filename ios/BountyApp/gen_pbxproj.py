#!/usr/bin/env python3
import hashlib, os

def suuid(seed="", suffix=""):
    return hashlib.md5((seed + suffix).encode()).hexdigest()[:24].upper()

PROJ_DIR = os.path.abspath(".")
APP_DIR = os.path.join(PROJ_DIR, "BountyApp")  # source directory name kept as-is

# Collect all files
swift_files = []
for root, dirs, files in os.walk(APP_DIR):
    rel = os.path.relpath(root, PROJ_DIR)
    for f in files:
        if not f.endswith(".swift"):
            continue
        path = os.path.join(rel, f)
        if "/App/" in path: grp = "App"
        elif "/Core/Components/" in path: grp = "Components"
        elif "/Core/Extensions/" in path: grp = "Extensions"
        elif "/Core/Network/" in path: grp = "Network"
        elif "/Core/" in path: grp = "Core"
        elif "/Features/Auth/" in path: grp = "Auth"
        elif "/Features/Camera/" in path: grp = "Camera"
        elif "/Features/Messages/" in path: grp = "Messages"
        elif "/Features/MyTasks/" in path: grp = "MyTasks"
        elif "/Features/Onboarding/" in path: grp = "Onboarding"
        elif "/Features/Profile/" in path: grp = "Profile"
        elif "/Features/Publish/" in path: grp = "Publish"
        elif "/Features/Review/" in path: grp = "Review"
        elif "/Features/Settings/" in path: grp = "Settings"
        elif "/Features/Square/" in path: grp = "Square"
        elif "/Features/TaskDetail/" in path: grp = "TaskDetail"
        elif "/Features/Wallet/" in path: grp = "Wallet"
        elif "/Models/" in path: grp = "Models"
        else: grp = "Core"
        swift_files.append((path, f, grp))

strings_files = []
for root, dirs, files in os.walk(APP_DIR):
    rel = os.path.relpath(root, PROJ_DIR)
    for f in files:
        if not f.endswith(".strings"):
            continue
        path = os.path.join(rel, f)
        if "en.lproj" in path: grp = "en_lproj"
        elif "zh-Hans.lproj" in path: grp = "zh_lproj"
        else: grp = "Resources"
        strings_files.append((path, f, grp))

xcassets_files = []
for root, dirs, files in os.walk(APP_DIR):
    rel = os.path.relpath(root, PROJ_DIR)
    for d in dirs:
        if d.endswith(".xcassets"):
            if "Resources" in rel:
                continue  # Skip empty Resources/Assets.xcassets
            xcassets_files.append((os.path.join(rel, d), d, "Resources"))

resource_files = []
for root, dirs, files in os.walk(APP_DIR):
    rel = os.path.relpath(root, PROJ_DIR)
    for f in files:
        if f.endswith(".xcprivacy"):
            resource_files.append((os.path.join(rel, f), f, "Resources"))

# Generate UUIDs
refs, builds, rbuilds = {}, {}, {}
import re
def qp(v):
    return f'"{v}"' if any(c in v for c in ['+','-','*','/','(',')',' ']) else v

for p, bn, _ in swift_files:
    refs[p] = suuid("fr", p)
    builds[p] = suuid("bf", p)
for p, bn, _ in strings_files:
    refs[p] = suuid("fr", p)
    rbuilds[p] = suuid("sb", p)
for p, bn, _ in xcassets_files:
    refs[p] = suuid("fr", p)
    rbuilds[p] = suuid("rb", p)
for p, bn, _ in resource_files:
    refs[p] = suuid("fr", p)
    rbuilds[p] = suuid("rf", p)

# UI test target sources (optional)
uitest_dir = "SeekerUITests"
uitest_files = []
if os.path.isdir(uitest_dir):
    for f in sorted(os.listdir(uitest_dir)):
        if f.endswith(".swift"):
            p = os.path.join(uitest_dir, f)
            refs[p] = suuid("utfr", p)
            builds[p] = suuid("utbf", p)
            uitest_files.append((p, f))

# Group children
def gc(grp):
    result = []
    for p, bn, g in swift_files + strings_files + xcassets_files + resource_files:
        if g == grp:
            result.append((refs[p], bn))
    return result

# Helper: write a PBXGroup
def wgroup(L, gid, gname, children, path_val=None):
    pv = path_val if path_val else gname
    L.append(f'\t\t{gid} /* {gname} */ = {{')
    L.append(f'\t\t\tisa = PBXGroup;')
    L.append(f'\t\t\tchildren = (')
    for cid, cn in children:
        L.append(f'\t\t\t\t{cid} /* {cn} */,')
    L.append(f'\t\t\t);')
    L.append(f'\t\t\tpath = {pv};')
    L.append(f'\t\t\tsourceTree = "<group>";')
    L.append(f'\t\t}};')

# ===== BUILD THE FILE =====
OUT = []
def a(s=""): OUT.append(s)

a("// !$*UTF8*$!")
a("{")
a("\tarchiveVersion = 1;")
a("\tclasses = {")
a("\t};")
a("\tobjectVersion = 56;")
ROOT = suuid("project")
a(f'\trootObject = {ROOT} /* Project object */;')
a("\tobjects = {")
a("")

# PBXBuildFile
a("/* Begin PBXBuildFile section */")
import re
def qp(v):
    return f'"{v}"' if any(c in v for c in ['+','-','*','/','(',')',' ']) else v

for p, bn, _ in swift_files:
    a(f'\t\t{builds[p]} /* {bn} in Sources */ = {{isa = PBXBuildFile; fileRef = {refs[p]} /* {bn} */; }};')
for p, bn, _ in strings_files:
    a(f'\t\t{rbuilds[p]} /* {bn} in Resources */ = {{isa = PBXBuildFile; fileRef = {refs[p]} /* {bn} */; }};')
for p, bn, _ in resource_files:
    a(f'\t\t{rbuilds[p]} /* {bn} in Resources */ = {{isa = PBXBuildFile; fileRef = {refs[p]} /* {bn} */; }};')
for p, bn, _ in xcassets_files:
    a(f'\t\t{rbuilds[p]} /* {bn} in Resources */ = {{isa = PBXBuildFile; fileRef = {refs[p]} /* {bn} */; }};')
for p, bn in uitest_files:
    a(f'\t\t{builds[p]} /* {bn} in Sources */ = {{isa = PBXBuildFile; fileRef = {refs[p]} /* {bn} */; }};')
a("/* End PBXBuildFile section */")
a("")

# PBXFileReference
a("/* Begin PBXFileReference section */")
import re
def qp(v):
    return f'"{v}"' if any(c in v for c in ['+','-','*','/','(',')',' ']) else v

for p, bn, _ in swift_files:
    a(f'\t\t{refs[p]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {qp(bn)}; sourceTree = "<group>"; }};')
for p, bn, _ in strings_files:
    a(f'\t\t{refs[p]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; path = {bn}; sourceTree = "<group>"; }};')
for p, bn, _ in resource_files:
    a(f'\t\t{refs[p]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = {qp(bn)}; sourceTree = "<group>"; }};')
for p, bn, _ in xcassets_files:
    a(f'\t\t{refs[p]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {bn}; sourceTree = "<group>"; }};')
PR = suuid("product")
a(f'\t\t{PR} /* Seeker.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Seeker.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
for p, bn in uitest_files:
    a(f'\t\t{refs[p]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {qp(bn)}; sourceTree = "<group>"; }};')
if uitest_files:
    UTP = suuid("utproduct")
    a(f'\t\t{UTP} /* SeekerUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SeekerUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
a("/* End PBXFileReference section */")
a("")

# PBXFrameworksBuildPhase
FP = suuid("frameworks")
a("/* Begin PBXFrameworksBuildPhase section */")
a(f'\t\t{FP} /* Frameworks */ = {{')
a(f'\t\t\tisa = PBXFrameworksBuildPhase;')
a(f'\t\t\tbuildActionMask = 2147483647;')
a(f'\t\t\tfiles = (')
a(f'\t\t\t);')
a(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
a(f'\t\t}};')
a("/* End PBXFrameworksBuildPhase section */")
a("")

# PBXGroup
a("/* Begin PBXGroup section */")
GRP = {}
all_grps = sorted(set(g for _,_,g in swift_files+strings_files+xcassets_files))
all_grps.append("Features")
for gn in all_grps:
    GRP[gn] = suuid("grp", gn)

path_map = {
    "App":"App","Components":"Components","Extensions":"Extensions","Network":"Network",
    "Auth":"Auth","Camera":"Camera","Messages":"Messages","MyTasks":"MyTasks",
    "Onboarding":"Onboarding","Profile":"Profile","Publish":"Publish",
    "Review":"Review","Settings":"Settings","Square":"Square",
    "TaskDetail":"TaskDetail","Wallet":"Wallet","Models":"Models",
    "Resources":"Resources",
    "en_lproj":"en.lproj","zh_lproj":"zh-Hans.lproj",
}

for gn in sorted(all_grps):
    if gn in ("Core", "Features"):
        continue
    wgroup(OUT, GRP[gn], gn, gc(gn), path_map.get(gn, gn))

# Core group
core_ch = []
for cg in ["Components", "Extensions", "Network"]:
    core_ch.append((GRP[cg], cg))
core_ch += [(refs[p], bn) for p, bn, g in swift_files+strings_files if g == "Core"]
wgroup(OUT, GRP["Core"], "Core", core_ch, "Core")

# Features group
feat_ch = [(GRP[fg], fg) for fg in ["Auth","Camera","Messages","MyTasks","Onboarding","Profile","Publish","Review","Settings","Square","TaskDetail","Wallet"]]
wgroup(OUT, GRP["Features"], "Features", feat_ch, "Features")

# Seeker main
MAIN = suuid("main")
ROOT_GROUP = suuid("rootgroup")
ROOT_GROUP = suuid("rootgroup")
a(f'\t\t{MAIN} /* Seeker */ = {{')
a(f'\t\t\tisa = PBXGroup;')
a(f'\t\t\tchildren = (')
for gn in ["App","Core","Features","Models","Resources","en_lproj","zh_lproj"]:
    a(f'\t\t\t\t{GRP[gn]} /* {gn} */,')
a(f'\t\t\t);')
a(f'\t\t\tpath = BountyApp;')
a(f'\t\t\tsourceTree = "<group>";')
a(f'\t\t}};')

# Root group
a(f'\t\t{ROOT_GROUP} = {{')
a(f'\t\t\tisa = PBXGroup;')
a(f'\t\t\tchildren = (')
a(f'\t\t\t\t{MAIN} /* Seeker */,')
if uitest_files:
    UTG = suuid("utgrp")
    a(f'\t\t\t\t{UTG} /* SeekerUITests */,')
PRODS = suuid("products")
a(f'\t\t\t\t{PRODS} /* Products */,')
a(f'\t\t\t);')
a(f'\t\t\tsourceTree = "<group>";')
a(f'\t\t}};')

# UI Tests group
if uitest_files:
    a(f'\t\t{UTG} /* SeekerUITests */ = {{')
    a(f'\t\t\tisa = PBXGroup;')
    a(f'\t\t\tchildren = (')
    for p, bn in uitest_files:
        a(f'\t\t\t\t{refs[p]} /* {bn} */,')
    a(f'\t\t\t);')
    a(f'\t\t\tpath = SeekerUITests;')
    a(f'\t\t\tsourceTree = "<group>";')
    a(f'\t\t}};')

# Products
a(f'\t\t{PRODS} /* Products */ = {{')
a(f'\t\t\tisa = PBXGroup;')
a(f'\t\t\tchildren = (')
a(f'\t\t\t\t{PR} /* Seeker.app */,')
if uitest_files:
    a(f'\t\t\t\t{UTP} /* SeekerUITests.xctest */,')
a(f'\t\t\t);')
a(f'\t\t\tname = Products;')
a(f'\t\t\tsourceTree = "<group>";')
a(f'\t\t}};')
a("/* End PBXGroup section */")
a("")

# PBXNativeTarget
TGT = suuid("target")
SP = suuid("sources")
RP = suuid("resources")
BCL_T = suuid("bclt")
a("/* Begin PBXNativeTarget section */")
a(f'\t\t{TGT} /* Seeker */ = {{')
a(f'\t\t\tisa = PBXNativeTarget;')
a(f'\t\t\tbuildConfigurationList = {BCL_T} /* Build configuration list for PBXNativeTarget "Seeker" */;')
a(f'\t\t\tbuildPhases = (')
a(f'\t\t\t\t{SP} /* Sources */,')
a(f'\t\t\t\t{FP} /* Frameworks */,')
a(f'\t\t\t\t{RP} /* Resources */,')
a(f'\t\t\t);')
a(f'\t\t\tbuildRules = (')
a(f'\t\t\t);')
a(f'\t\t\tdependencies = (')
a(f'\t\t\t);')
a(f'\t\t\tname = Seeker;')
a(f'\t\t\tproductName = Seeker;')
a(f'\t\t\tproductReference = {PR} /* Seeker.app */;')
a(f'\t\t\tproductType = "com.apple.product-type.application";')
a(f'\t\t}};')
if uitest_files:
    UST = suuid("uttarget")
    USP = suuid("utsources")
    UBCL = suuid("utbcl")
    a(f'\t\t{UST} /* SeekerUITests */ = {{')
    a(f'\t\t\tisa = PBXNativeTarget;')
    a(f'\t\t\tbuildConfigurationList = {UBCL} /* Build configuration list for PBXNativeTarget "SeekerUITests" */;')
    a(f'\t\t\tbuildPhases = (')
    a(f'\t\t\t\t{USP} /* Sources */,')
    a(f'\t\t\t);')
    a(f'\t\t\tbuildRules = (')
    a(f'\t\t\t);')
    a(f'\t\t\tdependencies = (')
    a(f'\t\t\t\t{suuid("utdep")} /* PBXTargetDependency */,')
    a(f'\t\t\t);')
a(f'\t\t\tname = SeekerUITests;')
a(f'\t\t\tproductName = SeekerUITests;')
a(f'\t\t\tproductReference = {UTP} /* SeekerUITests.xctest */;')
a(f'\t\t\tproductType = "com.apple.product-type.bundle.ui-testing";')
a(f'\t\t}};')
a("/* End PBXNativeTarget section */")
a("")

# PBXProject
BCL_P = suuid("bclp")
a("/* Begin PBXProject section */")
a(f'\t\t{ROOT} /* Project object */ = {{')
a(f'\t\t\tisa = PBXProject;')
a(f'\t\t\tattributes = {{')
a(f'\t\t\t\tBuildIndependentTargetsInParallel = 1;')
a(f'\t\t\t\tLastSwiftUpdateCheck = 1500;')
a(f'\t\t\t\tLastUpgradeCheck = 1500;')
a(f'\t\t\t\tTargetAttributes = {{')
a(f'\t\t\t\t\t{TGT} = {{')
a(f'\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;')
a(f'\t\t\t\t\t}};')
if uitest_files:
    a(f'\t\t\t\t\t{UST} = {{')
    a(f'\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;')
    a(f'\t\t\t\t\t\tTestTargetID = {TGT};')
    a(f'\t\t\t\t\t}};')
a(f'\t\t\t\t}};')
a(f'\t\t\t}};')
a(f'\t\t\tbuildConfigurationList = {BCL_P} /* Build configuration list for PBXProject "Seeker" */;')
a(f'\t\t\tcompatibilityVersion = "Xcode 14.0";')
a(f'\t\t\tdevelopmentRegion = "zh-Hans";')
a(f'\t\t\thasScannedForEncodings = 0;')
a(f'\t\t\tknownRegions = (')
a(f'\t\t\t\ten,')
a(f'\t\t\t\t"zh-Hans",')
a(f'\t\t\t);')
a(f'\t\t\tmainGroup = {ROOT_GROUP};')
a(f'\t\t\tproductRefGroup = {PRODS} /* Products */;')
a(f'\t\t\tprojectDirPath = "";')
a(f'\t\t\tprojectRoot = "";')
a(f'\t\t\ttargets = (')
a(f'\t\t\t\t{TGT} /* Seeker */,')
if uitest_files:
    a(f'\t\t\t\t{UST} /* SeekerUITests */,')
a(f'\t\t\t);')
a(f'\t\t}};')
a("/* End PBXProject section */")
a("")

# PBXResourcesBuildPhase
a("/* Begin PBXResourcesBuildPhase section */")
a(f'\t\t{RP} /* Resources */ = {{')
a(f'\t\t\tisa = PBXResourcesBuildPhase;')
a(f'\t\t\tbuildActionMask = 2147483647;')
a(f'\t\t\tfiles = (')
for p, bn, _ in strings_files:
    a(f'\t\t\t\t{rbuilds[p]} /* {bn} in Resources */,')
for p, bn, _ in resource_files:
    a(f'\t\t\t\t{rbuilds[p]} /* {bn} in Resources */,')
for p, bn, _ in xcassets_files:
    a(f'\t\t\t\t{rbuilds[p]} /* {bn} in Resources */,')
a(f'\t\t\t);')
a(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
a(f'\t\t}};')
a("/* End PBXResourcesBuildPhase section */")
a("")

# PBXSourcesBuildPhase
a("/* Begin PBXSourcesBuildPhase section */")
a(f'\t\t{SP} /* Sources */ = {{')
a(f'\t\t\tisa = PBXSourcesBuildPhase;')
a(f'\t\t\tbuildActionMask = 2147483647;')
a(f'\t\t\tfiles = (')
import re
def qp(v):
    return f'"{v}"' if any(c in v for c in ['+','-','*','/','(',')',' ']) else v

for p, bn, _ in swift_files:
    a(f'\t\t\t\t{builds[p]} /* {bn} in Sources */,')
a(f'\t\t\t);')
a(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
a(f'\t\t}};')
a("/* End PBXSourcesBuildPhase section */")

if uitest_files:
    a("/* Begin PBXSourcesBuildPhase section */")
    a(f'\t\t{USP} /* Sources */ = {{')
    a(f'\t\t\tisa = PBXSourcesBuildPhase;')
    a(f'\t\t\tbuildActionMask = 2147483647;')
    a(f'\t\t\tfiles = (')
    for p, bn in uitest_files:
        a(f'\t\t\t\t{builds[p]} /* {bn} in Sources */,')
    a(f'\t\t\t);')
    a(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a(f'\t\t}};')
    a("/* End PBXSourcesBuildPhase section */")
a("")

# XCBuildConfiguration
COM = {
    'ALWAYS_SEARCH_USER_PATHS':'NO',
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS':'YES',
    'CLANG_ANALYZER_NONNULL':'YES',
    'CLANG_CXX_LANGUAGE_STANDARD':'"gnu++20"',
    'CLANG_ENABLE_MODULES':'YES',
    'CLANG_ENABLE_OBJC_ARC':'YES',
    'COPY_PHASE_STRIP':'NO',
    'ENABLE_STRICT_OBJC_MSGSEND':'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING':'YES',
    'IPHONEOS_DEPLOYMENT_TARGET':'16.0',
    'LOCALIZATION_PREFERS_STRING_CATALOGS':'NO',
    'SDKROOT':'iphoneos',
}
TGT_SET = {
    'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon',
    'CODE_SIGN_STYLE':'Automatic',
    'CURRENT_PROJECT_VERSION':'1',
    'DEVELOPMENT_TEAM':'""',
    'ENABLE_PREVIEWS':'YES',
    'GENERATE_INFOPLIST_FILE':'YES',
    'INFOPLIST_KEY_CFBundleDisplayName':'Seeker',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES',
    'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents':'YES',
    'INFOPLIST_KEY_UILaunchScreen':'""',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
    'INFOPLIST_KEY_NSCameraUsageDescription':'"Seeker needs camera access to complete tasks"',
    'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription':'"Seeker needs location to find nearby tasks"',
    'MARKETING_VERSION':'1.0',
    'PRODUCT_BUNDLE_IDENTIFIER':'com.gotseeker.app',
    'PRODUCT_NAME':'"$(TARGET_NAME)"',
    'SWIFT_EMIT_LOC_STRINGS':'YES',
    'SWIFT_VERSION':'5.0',
    'TARGETED_DEVICE_FAMILY':'"1,2"',
}

DC = suuid("debug")
RC = suuid("release")
TD = suuid("tdebug")
TR = suuid("trelease")

a("/* Begin XCBuildConfiguration section */")

# Debug
a(f'\t\t{DC} /* Debug */ = {{')
a(f'\t\t\tisa = XCBuildConfiguration;')
a(f'\t\t\tbuildSettings = {{')
for k,v in COM.items():
    a(f'\t\t\t\t{k} = {v};')
a(f'\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;')
a(f'\t\t\t\tENABLE_TESTABILITY = YES;')
a(f'\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;')
a(f'\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
a(f'\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (')
a(f'\t\t\t\t\t"DEBUG=1",')
a(f'\t\t\t\t\t"$(inherited)",')
a(f'\t\t\t\t);')
a(f'\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;')
a(f'\t\t\t\tONLY_ACTIVE_ARCH = YES;')
a(f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;')
a(f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
a(f'\t\t\t}};')
a(f'\t\t\tname = Debug;')
a(f'\t\t}};')

# Release
a(f'\t\t{RC} /* Release */ = {{')
a(f'\t\t\tisa = XCBuildConfiguration;')
a(f'\t\t\tbuildSettings = {{')
for k,v in COM.items():
    a(f'\t\t\t\t{k} = {v};')
a(f'\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
a(f'\t\t\t\tENABLE_NS_ASSERTIONS = NO;')
a(f'\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;')
a(f'\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;')
a(f'\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
a(f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";')
a(f'\t\t\t\tVALIDATE_PRODUCT = YES;')
a(f'\t\t\t}};')
a(f'\t\t\tname = Release;')
a(f'\t\t}};')

# Target Debug
a(f'\t\t{TD} /* Debug */ = {{')
a(f'\t\t\tisa = XCBuildConfiguration;')
a(f'\t\t\tbuildSettings = {{')
for k,v in TGT_SET.items():
    a(f'\t\t\t\t{k} = {v};')
a(f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
a(f'\t\t\t\t\t"$(inherited)",')
a(f'\t\t\t\t\t"@executable_path/Frameworks",')
a(f'\t\t\t\t);')
a(f'\t\t\t}};')
a(f'\t\t\tname = Debug;')
a(f'\t\t}};')

# Target Release
a(f'\t\t{TR} /* Release */ = {{')
a(f'\t\t\tisa = XCBuildConfiguration;')
a(f'\t\t\tbuildSettings = {{')
for k,v in TGT_SET.items():
    a(f'\t\t\t\t{k} = {v};')
a(f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
a(f'\t\t\t\t\t"$(inherited)",')
a(f'\t\t\t\t\t"@executable_path/Frameworks",')
a(f'\t\t\t\t);')
a(f'\t\t\t}};')
a(f'\t\t\tname = Release;')
a(f'\t\t}};')

# UI Test Target configurations
if uitest_files:
    UTDC = suuid("utdebug")
    UTRC = suuid("utrelease")
    UT_SET = {
        'CODE_SIGN_STYLE':'Automatic',
        'CURRENT_PROJECT_VERSION':'1',
        'DEVELOPMENT_TEAM':'""',
        'GENERATE_INFOPLIST_FILE':'YES',
        'INFOPLIST_KEY_CFBundleDisplayName':'SeekerUITests',
        'INFOPLIST_KEY_UILaunchScreen':'""',
        'IPHONEOS_DEPLOYMENT_TARGET':'16.0',
        'MARKETING_VERSION':'1.0',
        'PRODUCT_BUNDLE_IDENTIFIER':'com.gotseeker.app.uitests',
        'PRODUCT_NAME':'"$(TARGET_NAME)"',
        'SWIFT_VERSION':'5.0',
        'TARGETED_DEVICE_FAMILY':'"1,2"',
        'TEST_TARGET_NAME':'Seeker',
        'USES_XCTRUNNER':'YES',
    }
    # Debug
    a(f'\t\t{UTDC} /* Debug */ = {{')
    a(f'\t\t\tisa = XCBuildConfiguration;')
    a(f'\t\t\tbuildSettings = {{')
    for k,v in UT_SET.items():
        a(f'\t\t\t\t{k} = {v};')
    a(f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
    a(f'\t\t\t\t\t"$(inherited)",')
    a(f'\t\t\t\t\t"@executable_path/Frameworks",')
    a(f'\t\t\t\t\t"@loader_path/Frameworks",')
    a(f'\t\t\t\t);')
    a(f'\t\t\t}};')
    a(f'\t\t\tname = Debug;')
    a(f'\t\t}};')
    # Release
    a(f'\t\t{UTRC} /* Release */ = {{')
    a(f'\t\t\tisa = XCBuildConfiguration;')
    a(f'\t\t\tbuildSettings = {{')
    for k,v in UT_SET.items():
        a(f'\t\t\t\t{k} = {v};')
    a(f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
    a(f'\t\t\t\t\t"$(inherited)",')
    a(f'\t\t\t\t\t"@executable_path/Frameworks",')
    a(f'\t\t\t\t\t"@loader_path/Frameworks",')
    a(f'\t\t\t\t);')
    a(f'\t\t\t}};')
    a(f'\t\t\tname = Release;')
    a(f'\t\t}};')
a("/* End XCBuildConfiguration section */")
a("")

# XCConfigurationList
a("/* Begin XCConfigurationList section */")
a(f'\t\t{BCL_P} /* Build configuration list for PBXProject "Seeker" */ = {{')
a(f'\t\t\tisa = XCConfigurationList;')
a(f'\t\t\tbuildConfigurations = (')
a(f'\t\t\t\t{DC} /* Debug */,')
a(f'\t\t\t\t{RC} /* Release */,')
a(f'\t\t\t);')
a(f'\t\t\tdefaultConfigurationIsVisible = 0;')
a(f'\t\t\tdefaultConfigurationName = Release;')
a(f'\t\t}};')
a(f'\t\t{BCL_T} /* Build configuration list for PBXNativeTarget "Seeker" */ = {{')
a(f'\t\t\tisa = XCConfigurationList;')
a(f'\t\t\tbuildConfigurations = (')
a(f'\t\t\t\t{TD} /* Debug */,')
a(f'\t\t\t\t{TR} /* Release */,')
a(f'\t\t\t);')
a(f'\t\t\tdefaultConfigurationIsVisible = 0;')
a(f'\t\t\tdefaultConfigurationName = Release;')
a(f'\t\t}};')
if uitest_files:
    a(f'\t\t{UBCL} /* Build configuration list for PBXNativeTarget "SeekerUITests" */ = {{')
    a(f'\t\t\tisa = XCConfigurationList;')
    a(f'\t\t\tbuildConfigurations = (')
    a(f'\t\t\t\t{UTDC} /* Debug */,')
    a(f'\t\t\t\t{UTRC} /* Release */,')
    a(f'\t\t\t);')
    a(f'\t\t\tdefaultConfigurationIsVisible = 0;')
    a(f'\t\t\tdefaultConfigurationName = Release;')
    a(f'\t\t}};')
a("/* End XCConfigurationList section */")
a("")

# PBXContainerItemProxy + PBXTargetDependency (test -> app)
if uitest_files:
    UCP = suuid("utproxy")
    a("/* Begin PBXContainerItemProxy section */")
    a(f'\t\t{UCP} /* PBXContainerItemProxy */ = {{')
    a(f'\t\t\tisa = PBXContainerItemProxy;')
    a(f'\t\t\tcontainerPortal = {ROOT} /* Project object */;')
    a(f'\t\t\tproxyType = 1;')
    a(f'\t\t\ttarget = {TGT} /* Seeker */;')
    a(f'\t\t\ttargetProxy = {PR} /* Seeker.app */;')
    a(f'\t\t}};')
    a("/* End PBXContainerItemProxy section */")
    a("")
    a("/* Begin PBXTargetDependency section */")
    a(f'\t\t{suuid("utdep")} /* PBXTargetDependency */ = {{')
    a(f'\t\t\tisa = PBXTargetDependency;')
    a(f'\t\t\ttarget = {TGT} /* Seeker */;')
    a(f'\t\t\ttargetProxy = {UCP} /* PBXContainerItemProxy */;')
    a(f'\t\t}};')
    a("/* End PBXTargetDependency section */")
    a("")

a("\t};")
a("}")

with open("BountyApp.xcodeproj/project.pbxproj", "w") as f:
    f.write("\n".join(OUT))

print(f"Generated {len(OUT)} lines: {len(swift_files)} swift, {len(strings_files)} strings, {len(xcassets_files)} assets")
