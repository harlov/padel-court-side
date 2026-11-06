"""Generate a dependency-free native iPhone + companion Watch Xcode project."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, kind, value):
    key = ident(name); objects[key] = f'isa = {kind}; {value}'; return key
def arr(items): return '(' + ', '.join(items) + ',)'
def quote(s): return '"' + s.replace('"', '\\"') + '"'
core = ['Sources/PadelCore/Match.swift', 'Shared/MatchStore.swift', 'Shared/Scoreboard.swift']
files = core + ['iPhone/PadelApp.swift', 'Watch/PadelWatchApp.swift']
refs = {p: add(p, 'PBXFileReference', f'lastKnownFileType = sourcecode.swift; path = {quote(p)}; sourceTree = SOURCE_ROOT;') for p in files}
products = {}
for target in ['PadelScore', 'PadelWatch']:
    products[target] = add(target+'product', 'PBXFileReference', f'explicitFileType = wrapper.application; path = {target}.app; sourceTree = BUILT_PRODUCTS_DIR;')
products_group = add('products', 'PBXGroup', f'children = {arr(products.values())}; name = Products; sourceTree = "<group>";')
main = add('main', 'PBXGroup', f'children = {arr(list(refs.values())+[products_group])}; sourceTree = "<group>";')
def configurations(name, settings):
    configs=[]
    for mode in ['Debug', 'Release']:
        s = dict(settings)
        s['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if mode == 'Debug' else '-O'
        if mode == 'Debug': s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        configs.append(add(name+mode, 'XCBuildConfiguration', 'buildSettings = {' + ' '.join(f'{k} = {quote(v)};' for k,v in s.items()) + f'}}; name = {mode};'))
    return add(name+'configs', 'XCConfigurationList', f'buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_configs = configurations('project', {'SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic'})
watch_id=ident('PadelWatchtarget')
proxy=add('watchproxy','PBXContainerItemProxy',f'containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {watch_id}; remoteInfo = PadelWatch;')
dependency=add('watchdependency','PBXTargetDependency',f'target = {watch_id}; targetProxy = {proxy};')
embedfile=add('embedwatch','PBXBuildFile', f'fileRef = {products["PadelWatch"]}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy,);}};')
embed=add('embed','PBXCopyFilesBuildPhase',f'buildActionMask = 2147483647; dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; dstSubfolderSpec = 16; files = ({embedfile},); runOnlyForDeploymentPostprocessing = 0;')
targets=[]
for name, source, watch in [('PadelScore','iPhone/PadelApp.swift',False),('PadelWatch','Watch/PadelWatchApp.swift',True)]:
    builds=[add(name+p,'PBXBuildFile',f'fileRef = {refs[p]};') for p in core+[source]]
    sources=add(name+'sources','PBXSourcesBuildPhase',f'buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    frameworks=add(name+'frameworks','PBXFrameworksBuildPhase','buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resources=add(name+'resources','PBXResourcesBuildPhase','buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    settings={'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'com.courtside.padelscore'+('.watchkitapp' if watch else ''), 'GENERATE_INFOPLIST_FILE':'YES','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1','TARGETED_DEVICE_FAMILY':'4' if watch else '1','SDKROOT':'watchos' if watch else 'iphoneos','SUPPORTED_PLATFORMS':'watchos watchsimulator' if watch else 'iphoneos iphonesimulator','INFOPLIST_KEY_CFBundleDisplayName':'Court Side', 'SWIFT_EMIT_LOC_STRINGS':'YES'}
    if watch:
        settings.update({'WATCHOS_DEPLOYMENT_TARGET':'10.0','INFOPLIST_KEY_WKCompanionAppBundleIdentifier':'com.courtside.padelscore','INFOPLIST_KEY_WKApplication':'YES'})
    else:
        settings.update({'IPHONEOS_DEPLOYMENT_TARGET':'17.0','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'})
    config=configurations(name,settings)
    targets.append(add(name+'target','PBXNativeTarget',f'buildConfigurationList = {config}; buildPhases = {arr([sources,frameworks,resources]+([] if watch else [embed]))}; buildRules = (); dependencies = {arr([] if watch else [dependency]) if not watch else "()"}; name = {name}; productName = {name}; productReference = {products[name]}; productType = "com.apple.product-type.application";'))
project=add('project','PBXProject',f'attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;}}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = {arr(targets)};')
text='// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
text+='\n'.join(f'{k} = {{{v}}};' for k,v in objects.items())
text+=f'\n}}; rootObject = {project}; }}\n'
(root/'PadelScore.xcodeproj/project.pbxproj').write_text(text)
