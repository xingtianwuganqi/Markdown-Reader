"""Generate a dependency-free, reproducible Xcode project using only Python stdlib."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
objects = []
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, body):
    objects.append(f'{ident(name)} = {{ {body} }};')
    return ident(name)
sources = sorted((root / 'MarkdownReader').rglob('*.swift'))
source_refs, build_refs = [], []
for path in sources:
    name = str(path.relative_to(root))
    ref = obj(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = SOURCE_ROOT;')
    source_refs.append(ref)
    build_refs.append(obj(name + '-build', f'isa = PBXBuildFile; fileRef = {ref};'))
asset = obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = MarkdownReader/Assets.xcassets; sourceTree = SOURCE_ROOT;')
asset_build = obj('asset-build', f'isa = PBXBuildFile; fileRef = {asset};')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = MarkdownReader.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
group = obj('main-group', f'isa = PBXGroup; children = ({",".join(source_refs + [asset, products])},); sourceTree = "<group>";')
sources_phase = obj('sources-phase', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(build_refs)},); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({asset_build},); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for scope in ['project', 'target']:
    configs = []
    for config in ['Debug', 'Release']:
        settings = {'SWIFT_VERSION':'6.0', 'CLANG_ENABLE_MODULES':'YES', 'IPHONEOS_DEPLOYMENT_TARGET':'18.0', 'MACOSX_DEPLOYMENT_TARGET':'15.0', 'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config == 'Debug' else '-O'}
        if scope == 'target':
            settings.update({'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'org.markdownreader.app', 'GENERATE_INFOPLIST_FILE':'YES', 'INFOPLIST_FILE':'MarkdownReader/Info.plist', 'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator macosx', 'SDKROOT':'auto', 'TARGETED_DEVICE_FAMILY':'1,2', 'SUPPORTS_MACCATALYST':'NO', 'CODE_SIGN_STYLE':'Automatic', 'COMBINE_HIDPI_IMAGES':'YES', 'CURRENT_PROJECT_VERSION':'1', 'MARKETING_VERSION':'0.1.0', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor', 'ENABLE_HARDENED_RUNTIME':'YES', 'CODE_SIGN_ENTITLEMENTS[sdk=macosx*]':'MarkdownReader/MarkdownReader.entitlements'})
        body = ' '.join(f'"{k}" = "{v}";' for k, v in settings.items())
        configs.append(obj(scope + config, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};'))
    obj(scope + '-config-list', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("target-config-list")}; buildPhases = ({sources_phase},{frameworks},{resources},); buildRules = (); dependencies = (); name = MarkdownReader; productName = MarkdownReader; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {ident("project-config-list")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en,Base,"zh-Hans",); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
(root / 'MarkdownReader.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
(root / 'MarkdownReader.xcodeproj/xcshareddata/xcschemes/MarkdownReader.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MarkdownReader.app" BlueprintName="MarkdownReader" ReferencedContainer="container:MarkdownReader.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MarkdownReader.app" BlueprintName="MarkdownReader" ReferencedContainer="container:MarkdownReader.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
