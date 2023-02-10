import "getImportCode"
--local directoryFilesList=FilesBrowserManager.directoryFilesList
local filesPositions=FilesBrowserManager.filesPositions
local adapterData=FilesBrowserManager.adapterData
local fileColors=FilesBrowserManager.fileColors
local fileIcons=FilesBrowserManager.fileIcons
local folderIcons=FilesBrowserManager.folderIcons
local relLibPathsMatch=FilesBrowserManager.relLibPathsMatch

local unknowString=getString(R.string.unknown)

local refresh=FilesBrowserManager.refresh
local getIconAlphaByName=FilesBrowserManager.getIconAlphaByName

local directoryFilesList
local highlightIndex

local function onClick(view)
  local data=view.tag._data
  local file=data.file
  local path=data.filePath
  local action=data.action
  switch action do
   case "createProject" then
    newSubActivity("NewProject")
   case "openProject" then
    ProjectManager.openProject(path)
   case "openFolder" then
    refresh(file,data.upFile)
   case "openFile" then
    local success,inThirdPartySoftware=FilesTabManager.openFile(file,data.fileType,false)
    if success and not(inThirdPartySoftware) then
      if screenConfigDecoder.deviceByWidth ~= "pc" then
        FilesBrowserManager.close()
      end
    end
  end
end
local onClickListener=View.OnClickListener({onClick=onClick})

local function onLongClick(view)
  --准备拖放
  recyclerView.tag.longClickedView=view
end
local onLongClickListener=View.OnLongClickListener({onLongClick=onLongClick})

local function fileMoreMenuClick(view)
  local tag=view.tag
  local popupMenu=tag.popupMenu
  popupMenu.show()
end

---加载工程图标
---@param iconUrl number|string
---@param iconView ImageView
---@param iconCard CardView
function loadPrjIcon(iconUrl,iconView,iconCard)
  if type(iconUrl)=="number" then
    iconView.setImageResource(iconUrl)
    if Build.VERSION.SDK_INT>=26 then--安卓8.0引入了自适应图标，因此将边框设为圆角
      iconCard.setRadius(math.dp2int(20))
      iconCard.setElevation(math.dp2int(1))
     else
      iconCard.setRadius(0)
      iconCard.setElevation(0)
    end
   else
    iconCard.setRadius(0)
    iconCard.setElevation(0)
    local options=RequestOptions()
    options.skipMemoryCache(true)--跳过内存缓存
    options.diskCacheStrategy(DiskCacheStrategy.NONE)--不缓冲disk硬盘中
    options.error(android.R.drawable.sym_def_app_icon)
    Glide.with(activity)
    .load(iconUrl)
    .apply(options)
    .listener({
      onResourceReady=function(resource, model, target, dataSource, isFirstResource)
        local bitmap=resource.getBitmap()
        local maxX=bitmap.getWidth()-1
        local maxY=bitmap.getHeight()-1
        --四周都有像素，说明是自适应图标
        if Color.alpha(bitmap.getPixel(0,0))>=0xFF
          and Color.alpha(bitmap.getPixel(maxX,0))>=0xFF
          and Color.alpha(bitmap.getPixel(0,maxY))>=0xFF
          and Color.alpha(bitmap.getPixel(maxX,maxY))>=0xFF then
          iconCard.setRadius(math.dp2int(20))
          iconCard.setElevation(math.dp2int(1))
        end
        return false
      end,
      onLoadFailed=function(e, model, target, isFirstResource)
        if Build.VERSION.SDK_INT>=26 then--安卓8.0引入了自适应图标，因此将边框设为圆角
          iconCard.setRadius(math.dp2int(20))
          iconCard.setElevation(math.dp2int(1))
        end
      end
    })
    .into(iconView)
  end
end

--根据打开状态确定view类型
local openState2ViewType={
  ["true"]={--index是位置索引，_else代表默认类型
    [0]=3,
    _else=4
  },
  ["false"]={
    [0]=1,
    _else=2
  }
}
return function(item)
  return LuaCustRecyclerAdapter(AdapterCreator({
    getItemCount=function()
      directoryFilesList=FilesBrowserManager.directoryFilesList
      highlightIndex=FilesBrowserManager.highlightIndex
      if directoryFilesList then
        return #directoryFilesList+1
       else
        return 0
      end
    end,
    getItemViewType=function(position)
      local son1=openState2ViewType[tostring(ProjectManager.openState)]
      return son1[position] or son1._else
    end,
    onCreateViewHolder=function(parent,viewType)
      local _,result=xpcall(function()
        local ids={}
        local view=loadlayout2(item[viewType],ids)
        local holder=LuaCustRecyclerHolder(view)
        view.setTag(ids)
        view.setBackground(ThemeUtil.getRippleDrawable(theme.color.rippleColorPrimary,true))
        view.setOnClickListener(onClickListener)
        view.setOnLongClickListener(onLongClickListener)

        if viewType==3 then
          local moreView=ids.more
          moreView.setBackground(ThemeUtil.getRippleDrawable(theme.color.rippleColorPrimary,true))
          moreView.onClick=fileMoreMenuClick
          local popupMenu=FilesBrowserManager.loadMoreMenu(moreView)
        end
        return holder
      end,
      function(err)
        showErrorDialog(err)
        return LuaCustRecyclerHolder(View(activity))
      end)
      return result
    end,

    onBindViewHolder=function(holder,position)
      local view=holder.view
      --tag就是装有view的字典
      local tag=view.getTag()
      local data=adapterData[position]
      local initData=false
      if not(data) then--没有data 说明需要初始化
        data={position=position}
        adapterData[position]=data
        initData=true
      end
      tag._data=data
      local titleView=tag.title
      local iconView=tag.icon
      local messageView=tag.message

      local file,filePath

      local projectOpenState=ProjectManager.openState
      if position==0 then--是第一项，就是新建项目或者返回上一目录
        if projectOpenState then--项目已打开，就是返回上一级
          if initData then
            file=FilesBrowserManager.directoryFile.getParentFile()
            if not(file) then--根目录的上一级是工程文件夹
              file=ProjectManager.projectsFile
            end
            data.file=file
            data.upFile=true
            data.action="openFolder"
          end
         else--项目没打开，就是创建项目选项
          data.action="createProject"
        end
       else--不是第一项
        if initData then
          file=directoryFilesList[position-1]
          filePath=file.getPath()
          data.file=file
          data.filePath=filePath
         else
          file=data.file
          filePath=data.filePath
        end

        if projectOpenState then
          local highLightCard=tag.highLightCard
          local fileName

          titleView.setText(fileName)
          if initData then
            fileName=file.getName()
            data.title=fileName
            data.fileName=fileName
           else
            fileName=data.fileName
          end
          titleView.setText(fileName)
          iconView.setAlpha(getIconAlphaByName(fileName))

          if file.isFile() then--当前是文件
            local colorFilter
            local fileType
            local icon
            if initData then
              filesPositions[filePath]=position
              fileType=getFileTypeByName(fileName)
              icon=fileIcons[fileType]
              data.fileType=fileType
              data.icon=icon
             else
              fileType=data.fileType
              icon=data.icon
            end
            iconView.setImageResource(icon)

            colorFilter=fileColors[fileType and string.upper(fileType)]

            if FilesTabManager.openState and FilesTabManager.file==file then
              titleView.setTextColor(theme.color.colorAccent)
              iconView.setColorFilter(theme.color.colorAccent)
              highLightCard.setCardBackgroundColor(theme.color.rippleColorAccent)
              view.setSelected(true)
              --保存一下当前打开文件的位置，方便后期切换文件
              FilesBrowserManager.nowFilePosition=position
             else
              titleView.setTextColor(theme.color.textColorPrimary)
              iconView.setColorFilter(colorFilter)
              highLightCard.setCardBackgroundColor(0)
              view.setSelected(false)
            end
            data.fileType=fileType
            data.action="openFile"
           else--当前是文件夹
            titleView.setTextColor(theme.color.textColorPrimary)
            iconView.setImageResource(folderIcons[fileName])
            iconView.setColorFilter(fileColors.folder)
            highLightCard.setCardBackgroundColor(0)
            view.setSelected(false)
            data.action="openFolder"
          end
          if highlightIndex and highlightIndex==position then
            titleView.setTextColor(0xff4caf50)--下次刷新时这个view的颜色会被上面的逻辑覆盖，因此不需要担心
          end

         else--未打开工程
          local pathView=tag.path
          local isLoadedConfig,config,iconUrl,title,summary
          if initData then
            isLoadedConfig,config=pcall(RePackTool.getConfigByProjectPath,filePath)
            local loadedRePackTool,rePackTool
            if isLoadedConfig then--文件没有损坏
              loadedRePackTool,rePackTool=pcall(RePackTool.getRePackToolByConfig,config)
              local mainProjectPath
              if loadedRePackTool then--可以加载二次打包工具
                mainProjectPath=RePackTool.getMainProjectDirByConfigAndRePackTool(filePath,config,rePackTool)
                title=(config.appName or unknowString)
               else--无法加载二次打包工具
                rePackTool=nil
                mainProjectPath=filePath.."/app/src/main"
                title=(config.appName or unknowString).." (Unable to get RePackTool)"
              end
              summary=config.packageName or unknowString
              iconUrl=ProjectManager.getProjectIconPath(config,filePath,mainProjectPath) or android.R.drawable.sym_def_app_icon
             else--文件已损坏
              title="(Unable to load config.lua)"
              summary=config
              config={}
              iconUrl=android.R.drawable.sym_def_app_icon
            end
            data.fileName=file.getName()
            data.title=title
            data.action="openProject"
            data.iconUrl=iconUrl
            data.config=config
            data.rePackTool=rePackTool
            data.summary=summary
            config,rePackTool=nil,nil
           else
            iconUrl=data.iconUrl
            config=data.config
            title=data.title
            summary=data.summary
          end
          titleView.setText(title)
          messageView.setText(summary)
          --按需显示工程存放位置
          --当工程路径为第一个工程路径，则不显示
          if file.getParent()==ProjectManager.projectsPath then
            pathView.setVisibility(View.GONE)
           else
            pathView.setText(filePath)
            pathView.setVisibility(View.VISIBLE)
          end

          local iconCard=tag.iconCard
          if highlightIndex and highlightIndex==position then
            titleView.setTextColor(0xff4caf50)
           else
            titleView.setTextColor(theme.color.textColorPrimary)
          end

          loadPrjIcon(iconUrl,iconView,iconCard)

        end
      end
    end,
  }))

end