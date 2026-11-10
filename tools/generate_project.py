"""Generate the self-contained Xcode project; Python standard library only."""
from pathlib import Path
import hashlib

def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

objects = []
def obj(name, body):
    objects.append(f'{uid(name)} = {{ {body} }};')
    return uid(name)

sources, resources, files = [], [], []
for folder, patterns in [('App', ['*.swift']), ('Resources', ['*.xcprivacy', '*.xcassets'])]:
    for pattern in patterns:
        for path in sorted(Path(folder).glob(pattern)):
            path = str(path)
            typ = 'sourcecode.swift' if path.endswith('.swift') else ('folder.assetcatalog' if path.endswith('.xcassets') else 'text.xml')
            ref = obj(path, f'isa = PBXFileReference; lastKnownFileType = {typ}; path = "{path}"; sourceTree = "<group>";')
            build = obj(path + '-build', f'isa = PBXBuildFile; fileRef = {ref};')
            files.append(ref)
            (sources if folder == 'App' else resources).append(build)

product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = MoonGoat.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
root = obj('root', f'isa = PBXGroup; children = ({",".join(files + [products])},); sourceTree = "<group>";')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = ".";')
core = obj('core', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = MoonGoatCore;')
corebuild = obj('corebuild', f'isa = PBXBuildFile; productRef = {core};')
frameworks = obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({corebuild},); runOnlyForDeploymentPostprocessing = 0;')
sources_phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(sources)},); runOnlyForDeploymentPostprocessing = 0;')
resources_phase = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resources)},); runOnlyForDeploymentPostprocessing = 0;')
project_configs, target_configs = [], []
for mode in ['Debug', 'Release']:
    project_configs.append(obj('project-' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES; }};'))
    optimization = '-Onone' if mode == 'Debug' else '-O'
    target_configs.append(obj('target-' + mode, f'''isa = XCBuildConfiguration; name = {mode}; buildSettings = {{
        PRODUCT_NAME = MoonGoat; PRODUCT_BUNDLE_IDENTIFIER = app.moongoat.ios;
        INFOPLIST_FILE = Resources/Info.plist; GENERATE_INFOPLIST_FILE = NO;
        MARKETING_VERSION = 0.1.3; CURRENT_PROJECT_VERSION = 4;
        TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        SUPPORTS_MACCATALYST = NO; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
        SWIFT_OPTIMIZATION_LEVEL = "{optimization}"; CODE_SIGN_STYLE = Automatic;
    }};'''))
project_list = obj('project-list', f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_list = obj('target-list', f'isa = XCConfigurationList; buildConfigurations = ({",".join(target_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'''isa = PBXNativeTarget; buildConfigurationList = {target_list}; buildPhases = ({sources_phase},{frameworks},{resources_phase},);
    buildRules = (); dependencies = (); name = MoonGoat; productName = MoonGoat;
    productReference = {product}; productType = "com.apple.product-type.application";
    packageProductDependencies = ({core},);''')
project = obj('project', f'''isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }};
    buildConfigurationList = {project_list}; compatibilityVersion = "Xcode 14.0";
    developmentRegion = zh-Hans; knownRegions = ("zh-Hans", en, Base,);
    mainGroup = {root}; productRefGroup = {products}; projectDirPath = ""; projectRoot = "";
    packageReferences = ({package},); targets = ({target},);''')
folder = Path('MoonGoat.xcodeproj')
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
scheme_dir = folder / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MoonGoat.app" BlueprintName="MoonGoat" ReferencedContainer="container:MoonGoat.xcodeproj"/>'
(scheme_dir / 'MoonGoat.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
