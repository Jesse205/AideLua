--NewProjectManager 是给主UI用的管理器，不能在线程里面使用
--导入 NewProjectManager 前必须先导入 NewProjectUtil2
local NewProjectManager = {}
local TEMPLATES_DIR_PATH = NewProjectUtil2.TEMPLATES_DIR_PATH --模板路径
local PRJS_PATH = NewProjectUtil2.PRJS_PATH --工程存放路径

NewProjectManager.TEMPLATES_DIR_PATH = TEMPLATES_DIR_PATH
NewProjectManager.PRJS_PATH = PRJS_PATH

--[[将错误代码转为文字
1: 不能为空
2: 项目已存在
]]
local errorCode2String = {
  [1] = activity.getString(R.string.jesse205_edit_error_cannotBeEmpty),
  [2] = activity.getString(R.string.project_exists)
}
NewProjectManager.errorCode2String = errorCode2String

--基础模板
local baseTemplateConfig = {
  keys = {
    androidX = false, --androidx启动开关，用于追加默认的androidx以及material依赖
    appName = "MyApplication", --默认应用名
    appPackageName = "com.aidelua.myapplication", --默认包名
    includeLua = {}, --config.lua的包含，只对项目根目录生效，第一个为主模块
    defaultImport = {}, --main.lua默认导入
    compileLua = true, --默认编译lua文件
  }
}

--[[加载模板
path: 模板路径
parentTemplateConfig: 父模板配置
]]
function NewProjectManager.loadTemplate(path, parentTemplateConfig)
  parentTemplateConfig = parentTemplateConfig or baseTemplateConfig
  local config = {}
  local configSuper = {
    parentTemplateConfig = parentTemplateConfig, --父模板配置
    parentTemplatePath = parentTemplateConfig.templatePath, --父模板配置
    templatePath = path, --模板路径
  }
  setmetatable(configSuper, { __index = _G })

  local configMetatable = { __index = configSuper } --统一metatable
  setmetatable(config, configMetatable)

  getConfigFromFile(path .. "/config.lua", config) --读取文件
  local subTemplates = config.subTemplates --获取子模板
  local subTemplatesMap = {} --子模板映射
  local templateType = config.templateType
  local pageConfigsListIndex = #pageConfigsList --为了按顺序添加页面
  if templateType then --有模板类型就添加到主模板映射
    templateMap[templateType] = config
  end
  configSuper.templateType = templateType --模板类型
  configSuper.templateConfig = config --模板配置

  configSuper.subTemplatesMap = subTemplatesMap --子模板映射

  setmetatable(config.keys, { __index = parentTemplateConfig.keys }) --可以直接访问父模板的变量

  --加载子模板
  if subTemplates then
    for index = 1, #subTemplates do
      local subTemplateName = subTemplates[index]
      subTemplatesMap[subTemplateName] = NewProjectManager.loadTemplate(path .. "/" .. subTemplateName, config)
    end
  end

  local pageConfigsPath = path .. "/pageConfigs.aly" --页面配置路径
  local pageConfigs = nil
  if File(pageConfigsPath).isFile() then
    pageConfigs = assert(loadfile(pageConfigsPath))()
    for index = 1, #pageConfigs do
      local pageConfig = pageConfigs[index]
      setmetatable(pageConfig, configMetatable)
      local subTemplateName = pageConfig.subTemplateName
      pageConfig.subTemplateConfig = subTemplatesMap[subTemplateName] --子模板配置
      pageConfig.subTemplatePath = path .. "/" .. subTemplateName --子模板路径
      pageConfigsListIndex = pageConfigsListIndex + 1
      table.insert(pageConfigsList, pageConfigsListIndex, pageConfig) --添加到页面列表
    end
  end

  return config
end

--仅检查工程是否存在，应用名为空等
function NewProjectManager.fastCheckAppNameError(appName)
  if appName == "" then
    return 1
   elseif File(PRJS_PATH .. "/" .. appName).exists() then
    return 2
  end
  return false
end

--仅检查包名为空等
function NewProjectManager.fastCheckPackageNameError(packageName)
  if packageName == "" then
    return 1
  end
  return false
end

---检查应用名，自动提示给用户，自动保存错误信息
---@param appName string 应用名
---@param appNameLay TextInputLayout 应用名编辑框的布局，主要用来显示错误信息
---@param config table 页面配置，用于在切换页面时的新建按钮可用判断
function NewProjectManager.checkAppName(appName, appNameLay, config)
  local appNameError = NewProjectManager.fastCheckAppNameError(appName)
  if appNameError then
    appNameLay
    .setError(errorCode2String[appNameError])
    .setErrorEnabled(true)
   else
    appNameLay.setErrorEnabled(false)
  end
  if config then
    config.appNameError = appNameError
  end
  return appNameError
end

---同上
function NewProjectManager.checkPackageName(packageName, packageNameLay, config)
  local packageNameError = NewProjectManager.fastCheckPackageNameError(packageName)
  if packageNameError then
    packageNameLay
    .setError(errorCode2String[packageNameError])
    .setErrorEnabled(true)
   else
    packageNameLay.setErrorEnabled(false)
  end
  if config then
    config.packageNameError = packageNameError
  end
  return packageNameError
end

--上面两个一块检查，包括创建按钮的状态
function NewProjectManager.checkAppConfigError(appName, packageName, appNameLay, packageNameLay, config)
  local appNameError = NewProjectManager.checkAppName(appName, appNameLay, config)
  local packageNameError = NewProjectManager.checkPackageName(packageName, packageNameLay, config)

  if appNameError or packageNameError then
    createButton.setEnabled(false)
    return true
   else
    createButton.setEnabled(true)
    return false
  end
end

--仅刷新创建按钮启用状态
function NewProjectManager.refreshCreateEnabled(config)
  if config.appNameError or config.packageNameError or config.helloWorld then
    createButton.setEnabled(false)
   else
    createButton.setEnabled(true)
  end
end

--为了方便存储数据
---写入ShaedData
---@param _type string 模板类型，建议唯一
---@param key string 键
---@param value Object 新值
function NewProjectManager.setSharedData(_type, key, value)
  return setSharedData("newproject_" .. _type .. "_" .. key, value)
end

---读取ShaedData
---@param _type string 模板类型，建议唯一
---@param key string 键
function NewProjectManager.getSharedData(_type, key)
  return getSharedData("newproject_" .. _type .. "_" .. key)
end

--刷新启用状态，比如AndroidX
---@param refreshType string 要刷新的类型，一般为"androidx"
---@param state boolean 状态
---@param chipsList table Chip列表，存放单个页面上所有的Chip
function NewProjectManager.refreshState(refreshType, state, chipsList)
  local notState = not (state)
  if refreshType == "androidx" then
    for index = 1, #chipsList do
      local chip = chipsList[index]
      local content = chip.tag
      local support = content.support
      if support then
        if (support == "androidx" and state) or (support == "normal" and notState) then
          chip.setEnabled(true)
          .setChecked(content.checked or false)
         elseif (support == "androidx" and notState) or (support == "normal" and state) then
          chip.setEnabled(false)
          .setChecked(false)
        end
      end
    end
  end
end

---为页面添加单选Chip
---@param group ChipGroup Chip的父布局
---@param chipConfig table Chip信息，1为名称，2为版本号，3为默认选中（仅selectedText为nil或者false时）
---@param selectedText string 已选中的Chip显示信息
---@param chipList table Chip列表，用于查看是否支持AndroidX
function NewProjectManager.addSingleChip(group,chipConfig,selectedText,_type,chipList)
  local title=chipConfig[1]
  local defaultChecked=chipConfig[3]
  local chip=Chip(activity)
  .setTag(chipConfig)
  .setText(title)
  .setCheckable(true)
  .setCheckedIconEnabled(false)
  group.addView(chip)
  table.insert(chipList,chip)
  if selectedText==title or selectedText==nil and defaultChecked then
    group.check(chip.getId())
  end
  return chip
end

---将普通的ChipGroup添加各种逻辑，使其成为单选的ChipGroup，并不断向pageConfig同步数据
---@param group ChipGroup 待改造的ChipGroup
---@param pageConfig table 页面配置
function NewProjectManager.applySingleCheckGroup(group,pageConfig,key)
  local oldSelectedId=group.getCheckedChipId()
  if oldSelectedId==-1 then
    local chip=group.getChildAt(0)
    if chip then
      group.check(chip.getId())
    end
   else
    local chip=group.findViewById(oldSelectedId)
    pageConfig[key]=chip.getTag()--保存数据到pageConfig
  end
  group.setOnCheckedChangeListener{
    onCheckedChanged=function(chipGroup, selectedId)
      if selectedId==-1 then
        local chip=chipGroup.findViewById(oldSelectedId)
        group.check(oldSelectedId)
       else
        oldSelectedId=selectedId
        local chip=chipGroup.findViewById(selectedId)
        pageConfig[key]=chip.getTag()--保存数据到pageConfig
        NewProjectManager.setSharedData(pageConfig._type, key,chip.getText())
      end
    end
  }
end

--view.tag={viewIndex=index,enabledList=list}
function NewProjectManager.onChipCheckChangedListener(view, isChecked)
  local config = view.tag
  local viewIndex = config.viewIndex
  local enabledList = config.enabledList
  if view.isEnabled() then --如果是启用状态，那么是主动的，就需要保存数据
    setSharedData("newproject_" .. config.path, isChecked)
    config.checked = isChecked
  end
  if isChecked then
    enabledList[viewIndex] = config
   else
    enabledList[viewIndex] = nil
  end
end

---构建前的数据准备，会调用 pageConfig.onBuildConfig，并自动转换为纯字符串或者列表。你只管调用就行了
---@param pageConfig table 页面配置
function NewProjectManager.buildConfig(pageConfig)
  --模板配置
  local templateConfig = pageConfig.templateConfig
  --当前子模板配置
  local subTemplateConfig = pageConfig.subTemplateConfig
  --所有涉及到的模板列表
  local templateConfigsList = { subTemplateConfig }

  --获取所有父模板配置，挨个添加到前面
  local localParentConfig = templateConfig --这是当前父模板
  while localParentConfig do
    table.insert(templateConfigsList, 1, localParentConfig)
    localParentConfig = localParentConfig.parentTemplateConfig
  end
  localParentConfig = nil --防止脑子短路，手动赋值为空

  local keys = {} --杂列表，需要用 NewProjectUtil2.buildKeyItem 生成字符串
  local formatList = {} --字符串列表
  local unzipList = {} --字符串列表

  local keysLists = {} --这是准备整合到keys的列表，一行一个keys

  for index = 1, #templateConfigsList do --开始添加列表
    local config = templateConfigsList[index]
    table.insert(keysLists, config.keys)
    if config.formatList then
      NewProjectUtil2.addItemsToTable(formatList, config.formatList)
    end
    if config.unzipList then
      NewProjectUtil2.addItemsToTable(unzipList, config.unzipList)
    end
  end

  --让系统帮你处理安卓x，但是在部分模板上可能有bug。
  local androidX = pageConfig.androidxState
  keys.androidX = androidX

  --响应构建key事件
  local onBuildConfig = pageConfig.onBuildConfig
  if onBuildConfig then
    onBuildConfig(pageConfig.ids, pageConfig, keysLists, formatList, unzipList)
  end

  --把keysLists整合到keys
  for index, content in pairs(keysLists) do --遍历列表
    for index, content in pairs(content) do --遍历Keys
      local oldContentList = keys[index]
      local _type = type(oldContentList)
      if _type == "table" then
        for index, content in ipairs(content) do
          table.insert(oldContentList, content)
        end --将新的值追加到原列表
       else
        keys[index] = content --覆盖原有值
      end
    end
  end

  local dependenciesEnd = keys.dependenciesEnd
  local appDependenciesEnd = keys.appDependenciesEnd
  if androidX then --启用AndroiX后自动追加。这里就可能有bug
    if dependenciesEnd then
      table.insert(dependenciesEnd, "api 'androidx.appcompat:appcompat:1.0.0'")
    end
    if appDependenciesEnd then
      table.insert(appDependenciesEnd, "api 'com.google.android.material:material:1.0.0'")
    end
  end

  return keys, formatList, unzipList
end

return NewProjectManager
