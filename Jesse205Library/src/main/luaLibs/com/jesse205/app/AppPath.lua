--import "android.os.Environment"
local AppPath={}
local context=jesse205.context
local packageName=context.getPackageName()


local sdcardPath=Environment.getExternalStorageDirectory().getPath()--SD卡的目录

--将默认目录设为“/sdcard/Android/data/Package Name/files”
local sdcardDataDirPath="Android/data/"..packageName
context.setLuaExtDir(sdcardDataDirPath.."/files")
local dataDirPath="/data/data/"..packageName
sdcardDataDirPath=sdcardPath.."/"..sdcardDataDirPath
local mediaDirPath=sdcardPath.."/Android/media/"..packageName--共享文件夹

local function getAppPublicPath(name)--获取自身公共路径
  return sdcardPath.."/"..name.."/Edde software/"..jesse205.appName
end

AppPath.Sdcard=sdcardPath 

AppPath.Temp=context.getLuaExtDir("temp")--临时目录

AppPath.Downloads=getAppPublicPath("Downloads")
AppPath.Movies=getAppPublicPath("Movies")
AppPath.Pictures=getAppPublicPath("Pictures")
AppPath.Music=getAppPublicPath("Music")

AppPath.LuaDir=context.getLuaDir()
AppPath.AppMediaDir=mediaDirPath.."/files"
AppPath.AppDataDir=dataDirPath.."/files"
AppPath.AppSdcardDataDir=sdcardDataDirPath.."/files"

AppPath.AppMediaCacheDir=mediaDirPath.."/cache"
AppPath.AppDataCacheDir=dataDirPath.."/cache"
AppPath.AppSdcardDataCacheDir=sdcardDataDirPath.."/cache"

return AppPath