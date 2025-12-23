// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  ========================================
//  🎮 ViewController.swift - 主界面控制器
//  ========================================
//
//  这是应用的【主界面控制器】，负责管理用户交互和界面显示
//
//  🔑 关键概念：
//  - ViewController 是 MVC 架构中的 C（Controller），负责协调 Model 和 View
//  - 它接收用户输入，处理业务逻辑，更新界面显示
//
//  📚 这个文件的主要功能：
//  1. 展示相机实时画面和 YOLO 检测结果
//  2. 管理任务切换（检测、分割、分类、姿态估计、OBB）
//  3. 管理模型选择和加载
//  4. 处理模型下载进度显示
//  5. 分享检测结果
//

import AVFoundation    // 📌 音视频处理框架（相机功能需要）
import AudioToolbox    // 📌 音频工具箱（播放系统声音）
import CoreML          // 📌 Core ML 框架（机器学习模型运行）
import CoreMedia       // 📌 媒体处理框架（处理视频帧）
import UIKit           // 📌 用户界面框架（所有 UI 组件的基础）
import YOLO            // 📌 YOLO SDK（封装了 YOLO 模型的推理逻辑）


// ============================================
// 📦 ModelTableViewCell - 模型列表单元格
// ============================================
/// 自定义的表格单元格，用于显示模型名称和下载状态
/// 
/// 📌 学习要点：
/// - UITableViewCell 是表格视图中每一行的基本单位
/// - 通过自定义 Cell 可以实现个性化的列表项布局
class ModelTableViewCell: UITableViewCell {
  
  /// 单元格的重用标识符
  /// 📌 iOS 使用重用机制优化表格性能：滚动时复用已创建的 Cell
  static let identifier = "ModelTableViewCell"

  /// 模型名称标签
  /// 📌 使用闭包语法创建并配置 UI 组件（这是一种常见的 Swift 模式）
  private let modelNameLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center           // 文本居中对齐
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)  // 中等粗细的14号字体
    label.translatesAutoresizingMaskIntoConstraints = false      // 使用 Auto Layout
    // 配置文本自动缩放（当文本过长时自动缩小字体）
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.7  // 最小缩放到 70%
    label.lineBreakMode = .byClipping  // 超出部分直接裁剪
    return label
  }()

  /// 下载图标（云朵+箭头图标）
  /// 📌 当模型需要从远程下载时显示此图标
  private let downloadIconImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "icloud.and.arrow.down"))
    imageView.tintColor = .white            // 图标颜色为白色
    imageView.contentMode = .scaleAspectFit // 保持宽高比缩放
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isHidden = true               // 默认隐藏
    return imageView
  }()

  /// 代码初始化方法
  /// 📌 当使用代码创建 Cell 时调用
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupUI()
  }

  /// Storyboard/XIB 初始化方法
  /// 📌 当从 Storyboard 加载 Cell 时调用（这里不使用，所以抛出错误）
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// 设置 UI 布局
  private func setupUI() {
    backgroundColor = .clear     // 背景透明
    selectionStyle = .default    // 使用默认选中样式

    // 将子视图添加到 contentView（Cell 的内容容器）
    contentView.addSubview(modelNameLabel)
    contentView.addSubview(downloadIconImageView)

    // ============================================
    // 📐 Auto Layout 约束设置
    // ============================================
    // 📌 Auto Layout 是 iOS 的自适应布局系统
    // 📌 通过约束（Constraint）定义视图之间的位置关系
    NSLayoutConstraint.activate([
      // 标签居中显示
      modelNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      modelNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      // 左边距至少 8 点
      modelNameLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
      // 与下载图标保持 4 点间距
      modelNameLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: downloadIconImageView.leadingAnchor, constant: -4),

      // 下载图标靠右显示
      downloadIconImageView.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor, constant: -4),
      downloadIconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      downloadIconImageView.widthAnchor.constraint(equalToConstant: 16),
      downloadIconImageView.heightAnchor.constraint(equalToConstant: 16),
    ])

    // 配置选中状态的背景视图
    let selectedBGView = UIView()
    selectedBGView.backgroundColor = UIColor(white: 1.0, alpha: 0.3)  // 半透明白色
    selectedBGView.layer.cornerRadius = 5   // 圆角
    selectedBGView.layer.masksToBounds = true
    selectedBackgroundView = selectedBGView
  }

  /// 配置单元格内容
  /// - Parameters:
  ///   - modelName: 模型显示名称
  ///   - isRemote: 是否为远程模型
  ///   - isDownloaded: 是否已下载
  func configure(with modelName: String, isRemote: Bool, isDownloaded: Bool) {
    modelNameLabel.text = modelName

    // 只对未下载的远程模型显示下载图标
    let showDownloadIcon = isRemote && !isDownloaded
    downloadIconImageView.isHidden = !showDownloadIcon

    // 根据图标显示状态调整标签布局优先级
    if showDownloadIcon {
      modelNameLabel.textAlignment = .center
      modelNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      modelNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    } else {
      modelNameLabel.textAlignment = .center
      modelNameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
      modelNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
  }

  /// 布局子视图时调用
  /// 📌 当 Cell 大小改变时，调整选中背景的大小
  override func layoutSubviews() {
    super.layoutSubviews()

    if let selectedBGView = selectedBackgroundView {
      selectedBGView.frame = bounds.insetBy(dx: 2, dy: 1)
    }
  }
}


// ============================================
// 🎮 ViewController - 主视图控制器
// ============================================
/// 应用的主视图控制器，管理所有界面交互
///
/// 📌 继承关系：
/// - UIViewController: iOS 视图控制器基类
/// - YOLOViewDelegate: YOLO 视图的代理协议，接收检测结果回调
class ViewController: UIViewController, YOLOViewDelegate {

  // ============================================
  // 📍 IBOutlet - 与 Storyboard 连接的 UI 组件
  // ============================================
  // 📌 @IBOutlet 表示这些属性会在 Storyboard 中连接到对应的 UI 元素
  // 📌 weak 表示弱引用，避免循环引用导致内存泄漏
  
  /// YOLO 视图 - 显示相机画面和检测结果
  @IBOutlet weak var yoloView: YOLOView!
  
  /// 根视图
  @IBOutlet var View0: UIView!
  
  /// 任务切换分段控件（Classify/Segment/Detect/Pose/OBB）
  @IBOutlet var segmentedControl: UISegmentedControl!
  
  /// 当前模型名称标签
  @IBOutlet weak var labelName: UILabel!
  
  /// FPS 和推理时间标签
  @IBOutlet weak var labelFPS: UILabel!
  
  /// 版本号标签
  @IBOutlet weak var labelVersion: UILabel!
  
  /// 加载指示器（转圈动画）
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  /// 对焦框图片
  @IBOutlet weak var focus: UIImageView!
  
  /// 公司 Logo 图片
  @IBOutlet weak var logoImage: UIImageView!

  // ============================================
  // 📍 私有属性
  // ============================================
  
  /// 选择反馈生成器（提供触觉反馈）
  /// 📌 当用户切换任务或选择模型时，设备会轻微震动
  let selection = UISelectionFeedbackGenerator()
  
  /// 是否是首次加载
  var firstLoad = true

  /// 下载进度条
  private let downloadProgressView: UIProgressView = {
    let pv = UIProgressView(progressViewStyle: .default)
    pv.progress = 0.0        // 初始进度为 0
    pv.isHidden = true       // 默认隐藏
    return pv
  }()

  /// 下载进度标签（显示 "Downloading 50%"）
  private let downloadProgressLabel: UILabel = {
    let label = UILabel()
    label.text = ""
    label.textAlignment = .center
    label.textColor = .systemGray
    label.font = UIFont.systemFont(ofSize: 14)
    label.isHidden = true
    return label
  }()

  /// 加载遮罩层（模型加载时显示半透明黑色遮罩）
  private var loadingOverlayView: UIView?

  /// 显示加载遮罩
  func showLoadingOverlay() {
    guard loadingOverlayView == nil else { return }
    let overlay = UIView(frame: view.bounds)
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)

    view.addSubview(overlay)
    loadingOverlayView = overlay
    view.bringSubviewToFront(downloadProgressView)
    view.bringSubviewToFront(downloadProgressLabel)

    view.isUserInteractionEnabled = false  // 禁用用户交互
  }

  /// 隐藏加载遮罩
  func hideLoadingOverlay() {
    loadingOverlayView?.removeFromSuperview()
    loadingOverlayView = nil
    view.isUserInteractionEnabled = true   // 恢复用户交互
  }

  // ============================================
  // 📍 任务和模型配置
  // ============================================
  
  /// 支持的 YOLO 任务列表
  /// 📌 元组数组：(显示名称, 模型文件夹名)
  private let tasks: [(name: String, folder: String)] = [
    ("Classify", "ClassifyModels"),  // 图像分类
    ("Segment", "SegmentModels"),    // 语义分割
    ("Detect", "DetectModels"),      // 目标检测
    ("Pose", "PoseModels"),          // 姿态估计
    ("OBB", "OBBModels"),            // 旋转框检测 (Oriented Bounding Box)
  ]

  /// 每个任务对应的本地模型文件列表
  private var modelsForTask: [String: [String]] = [:]

  /// 当前任务下可用的模型列表（包含本地和远程模型）
  private var currentModels: [ModelEntry] = []

  /// 当前选中的任务名称
  private var currentTask: String = ""
  
  /// 当前加载的模型名称
  private var currentModelName: String = ""

  /// 模型是否正在加载中
  private var isLoadingModel = false

  /// 模型选择列表（表格视图）
  private let modelTableView: UITableView = {
    let table = UITableView()
    table.isHidden = true
    table.layer.cornerRadius = 5
    table.clipsToBounds = true
    return table
  }()

  /// 模型列表背景视图
  private let tableViewBGView = UIView()

  /// 当前选中的模型索引
  private var selectedIndexPath: IndexPath?

  // ============================================
  // 🚀 viewDidLoad - 视图加载完成
  // ============================================
  /// 视图加载完成后调用，是进行初始化设置的最佳位置
  /// 
  /// 📌 生命周期说明：
  /// 1. init -> 2. loadView -> 3. viewDidLoad -> 4. viewWillAppear -> 5. viewDidAppear
  override func viewDidLoad() {
    super.viewDidLoad()

    // 1️⃣ 初始化任务分段控件
    setupTaskSegmentedControl()
    
    // 2️⃣ 加载所有任务的本地模型文件
    loadModelsForAllTasks()

    // 3️⃣ 默认选中 "Detect" 任务（索引为 2）
    if tasks.indices.contains(2) {
      segmentedControl.selectedSegmentIndex = 2
      currentTask = tasks[2].name
      reloadModelEntriesAndLoadFirst(for: currentTask)
    }

    // 4️⃣ 设置模型选择表格
    setupTableView()
    
    // 5️⃣ 配置 Logo 点击手势（点击跳转到官网）
    logoImage.isUserInteractionEnabled = true
    logoImage.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(logoButton)))
    
    // 6️⃣ 配置分享按钮
    yoloView.shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)

    // 7️⃣ 设置 YOLO 视图代理（接收检测结果回调）
    yoloView.delegate = self
    yoloView.labelName.isHidden = true
    yoloView.labelFPS.isHidden = true

    // 8️⃣ 强制设置标签文字颜色为白色
    labelName.textColor = .white
    labelFPS.textColor = .white
    labelVersion.textColor = .white

    // 9️⃣ 设置版本号显示
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
      labelVersion.text = "v\(version) (\(build))"
    }

    // 🔟 设置深色模式
    labelName.overrideUserInterfaceStyle = .dark
    labelFPS.overrideUserInterfaceStyle = .dark
    labelVersion.overrideUserInterfaceStyle = .dark

    // 1️⃣1️⃣ 配置下载进度 UI
    downloadProgressView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(downloadProgressView)

    downloadProgressLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(downloadProgressLabel)

    // 设置下载进度 UI 的约束
    NSLayoutConstraint.activate([
      downloadProgressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      downloadProgressView.topAnchor.constraint(
        equalTo: activityIndicator.bottomAnchor, constant: 8),
      downloadProgressView.widthAnchor.constraint(equalToConstant: 200),
      downloadProgressView.heightAnchor.constraint(equalToConstant: 2),

      downloadProgressLabel.centerXAnchor.constraint(equalTo: downloadProgressView.centerXAnchor),
      downloadProgressLabel.topAnchor.constraint(
        equalTo: downloadProgressView.bottomAnchor, constant: 8),
    ])

    // 1️⃣2️⃣ 配置下载进度回调
    ModelDownloadManager.shared.progressHandler = { [weak self] progress in
      guard let self = self else { return }
      DispatchQueue.main.async {
        self.downloadProgressView.progress = Float(progress)
        self.downloadProgressLabel.isHidden = false
        let percentage = Int(progress * 100)
        self.downloadProgressLabel.text = "Downloading \(percentage)%"
      }
    }
  }

  // ============================================
  // 📍 视图生命周期方法
  // ============================================
  
  /// 视图即将显示时调用
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    enforceWhiteTextColor()
    view.overrideUserInterfaceStyle = .dark
  }

  /// 特征集合改变时调用（如深色/浅色模式切换）
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    enforceWhiteTextColor()
  }

  /// 强制设置标签为白色文字
  private func enforceWhiteTextColor() {
    labelName.textColor = .white
    labelFPS.textColor = .white
    labelVersion.textColor = .white
  }

  // ============================================
  // 📍 任务和模型管理
  // ============================================
  
  /// 设置任务分段控件
  private func setupTaskSegmentedControl() {
    segmentedControl.removeAllSegments()
    for (index, taskInfo) in tasks.enumerated() {
      segmentedControl.insertSegment(withTitle: taskInfo.name, at: index, animated: false)
    }
  }

  /// 加载所有任务的本地模型文件
  /// 📌 遍历 App Bundle 中的模型文件夹，获取 .mlmodel 或 .mlpackage 文件
  private func loadModelsForAllTasks() {
    for taskInfo in tasks {
      let taskName = taskInfo.name
      let folderName = taskInfo.folder
      let modelFiles = getModelFiles(in: folderName)
      modelsForTask[taskName] = modelFiles
    }
  }

  /// 获取指定文件夹中的模型文件
  /// - Parameter folderName: 模型文件夹名称
  /// - Returns: 模型文件名数组
  private func getModelFiles(in folderName: String) -> [String] {
    // 获取文件夹 URL
    guard let folderURL = Bundle.main.url(forResource: folderName, withExtension: nil) else {
      return []
    }
    do {
      // 读取文件夹内容
      let fileURLs = try FileManager.default.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      // 筛选 .mlmodel 和 .mlpackage 文件
      let modelFiles =
        fileURLs
        .filter { $0.pathExtension == "mlmodel" || $0.pathExtension == "mlpackage" }
        .map { $0.lastPathComponent }

      // 对检测模型进行特殊排序
      if folderName == "DetectModels" {
        return reorderDetectionModels(modelFiles)
      } else {
        return modelFiles.sorted()
      }

    } catch {
      print("Error reading contents of folder \(folderName): \(error)")
      return []
    }
  }

  /// 重新排序检测模型
  /// 📌 将官方 YOLO 模型按大小排序（n < m < s < l < x）
  private func reorderDetectionModels(_ fileNames: [String]) -> [String] {
    // 官方模型大小后缀的排序权重
    let officialOrder: [Character: Int] = ["n": 0, "m": 1, "s": 2, "l": 3, "x": 4]

    var customModels: [String] = []    // 自定义模型
    var officialModels: [String] = []  // 官方模型

    for fileName in fileNames {
      let baseName = (fileName as NSString).deletingPathExtension.lowercased()

      // 判断是否为官方 YOLO 模型
      if baseName.hasPrefix("yolo"),
        let lastChar = baseName.last,
        officialOrder.keys.contains(lastChar)
      {
        officialModels.append(fileName)
      } else {
        customModels.append(fileName)
      }
    }

    // 自定义模型按字母排序
    customModels.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    // 官方模型按大小排序
    officialModels.sort { fileA, fileB in
      let baseA = (fileA as NSString).deletingPathExtension.lowercased()
      let baseB = (fileB as NSString).deletingPathExtension.lowercased()
      guard let lastA = baseA.last, let lastB = baseB.last,
        let indexA = officialOrder[lastA], let indexB = officialOrder[lastB]
      else {
        return baseA < baseB
      }
      return indexA < indexB
    }

    // 自定义模型在前，官方模型在后
    return customModels + officialModels
  }

  /// 重新加载模型列表并加载第一个模型
  private func reloadModelEntriesAndLoadFirst(for taskName: String) {
    currentModels = makeModelEntries(for: taskName)

    if !currentModels.isEmpty {
      modelTableView.isHidden = false
      modelTableView.reloadData()

      // 选中并加载第一个模型
      DispatchQueue.main.async {
        let firstIndex = IndexPath(row: 0, section: 0)
        self.modelTableView.selectRow(at: firstIndex, animated: false, scrollPosition: .none)
        self.selectedIndexPath = firstIndex
        let firstModel = self.currentModels[0]
        self.loadModel(entry: firstModel, forTask: taskName)
      }
    } else {
      print("No models found for task: \(taskName)")
      modelTableView.isHidden = true
    }
  }

  /// 构建模型条目列表（合并本地和远程模型）
  private func makeModelEntries(for taskName: String) -> [ModelEntry] {
    // 本地模型条目
    let localFileNames = modelsForTask[taskName] ?? []
    let localEntries = localFileNames.map { fileName -> ModelEntry in
      let display = (fileName as NSString).deletingPathExtension
      return ModelEntry(
        displayName: display,
        identifier: fileName,
        isLocalBundle: true,
        isRemote: false,
        remoteURL: nil
      )
    }

    // 获取本地模型名称集合（用于去重）
    let localModelNames = Set(localEntries.map { $0.displayName.lowercased() })

    // 远程模型条目（排除已有本地版本的模型）
    let remoteList = remoteModelsInfo[taskName] ?? []
    let remoteEntries = remoteList.compactMap { (modelName, url) -> ModelEntry? in
      guard !localModelNames.contains(modelName.lowercased()) else { return nil }
      
      return ModelEntry(
        displayName: modelName,
        identifier: modelName,
        isLocalBundle: false,
        isRemote: true,
        remoteURL: url
      )
    }

    return localEntries + remoteEntries
  }

  // ============================================
  // 📍 模型加载
  // ============================================
  
  /// 加载指定的模型
  /// - Parameters:
  ///   - entry: 模型条目
  ///   - task: 任务名称
  private func loadModel(entry: ModelEntry, forTask task: String) {
    // 防止重复加载
    guard !isLoadingModel else {
      print("Model is already loading. Please wait.")
      return
    }
    isLoadingModel = true
    
    // 重置 YOLO 视图的检测层
    yoloView.resetLayers()
    
    // 非首次加载时显示遮罩
    if !firstLoad {
      showLoadingOverlay()
      yoloView.setInferenceFlag(ok: false)
    } else {
      firstLoad = false
    }

    // 显示加载指示器
    self.activityIndicator.startAnimating()
    self.downloadProgressView.progress = 0.0
    self.downloadProgressView.isHidden = true
    self.downloadProgressLabel.isHidden = true
    self.view.isUserInteractionEnabled = false
    self.modelTableView.isUserInteractionEnabled = false

    print("Start loading model: \(entry.displayName)")

    // 根据模型来源选择加载方式
    if entry.isLocalBundle {
      // ============================================
      // 📦 加载本地 Bundle 中的模型
      // ============================================
      DispatchQueue.global().async { [weak self] in
        guard let self = self else { return }
        let yoloTask = self.convertTaskNameToYOLOTask(task)

        // 获取模型文件路径
        guard let folderURL = self.tasks.first(where: { $0.name == task })?.folder,
          let folderPathURL = Bundle.main.url(forResource: folderURL, withExtension: nil)
        else {
          DispatchQueue.main.async {
            self.finishLoadingModel(success: false, modelName: entry.displayName)
          }
          return
        }

        let modelURL = folderPathURL.appendingPathComponent(entry.identifier)
        DispatchQueue.main.async {
          self.downloadProgressLabel.isHidden = false
          self.downloadProgressLabel.text = "Loading \(entry.displayName)"
          // 设置模型到 YOLO 视图
          self.yoloView.setModel(modelPathOrName: modelURL.path, task: yoloTask) { result in
            switch result {
            case .success():
              self.finishLoadingModel(success: true, modelName: entry.displayName)
            case .failure(let error):
              print(error)
              self.finishLoadingModel(success: false, modelName: entry.displayName)
            }
          }
        }
      }
    } else {
      // ============================================
      // ☁️ 加载远程/缓存模型
      // ============================================
      let yoloTask = self.convertTaskNameToYOLOTask(task)
      let key = entry.identifier

      // 检查是否已缓存
      if ModelCacheManager.shared.isModelDownloaded(key: key) {
        loadCachedModelAndSetToYOLOView(
          key: key, yoloTask: yoloTask, displayName: entry.displayName)
      } else {
        // 需要下载
        guard let remoteURL = entry.remoteURL else {
          self.finishLoadingModel(success: false, modelName: entry.displayName)
          return
        }

        // 显示下载进度 UI
        self.downloadProgressView.progress = 0.0
        self.downloadProgressView.isHidden = false
        self.downloadProgressLabel.isHidden = false

        let localZipFileName = remoteURL.lastPathComponent

        // 开始下载
        ModelCacheManager.shared.loadModel(
          from: localZipFileName,
          remoteURL: remoteURL,
          key: key
        ) { [weak self] mlModel, loadedKey in
          guard let self = self else { return }
          if mlModel == nil {
            self.finishLoadingModel(success: false, modelName: entry.displayName)
            return
          }
          self.loadCachedModelAndSetToYOLOView(
            key: loadedKey,
            yoloTask: yoloTask,
            displayName: entry.displayName)
        }
      }
    }
  }

  /// 加载已缓存的模型并设置到 YOLO 视图
  private func loadCachedModelAndSetToYOLOView(key: String, yoloTask: YOLOTask, displayName: String) {
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let localModelURL = documentsDirectory.appendingPathComponent(key).appendingPathExtension("mlmodelc")

    DispatchQueue.main.async {
      self.downloadProgressLabel.isHidden = false
      self.downloadProgressLabel.text = "Loading \(displayName)"
      self.yoloView.setModel(modelPathOrName: localModelURL.path, task: yoloTask) { result in
        switch result {
        case .success():
          self.finishLoadingModel(success: true, modelName: displayName)
        case .failure(let error):
          print(error)
          self.finishLoadingModel(success: false, modelName: displayName)
        }
      }
    }
  }

  /// 模型加载完成的处理
  private func finishLoadingModel(success: Bool, modelName: String) {
    DispatchQueue.main.async {
      // 停止加载动画
      self.activityIndicator.stopAnimating()
      self.downloadProgressView.isHidden = true
      self.downloadProgressLabel.isHidden = true

      // 恢复用户交互
      self.view.isUserInteractionEnabled = true
      self.modelTableView.isUserInteractionEnabled = true
      self.isLoadingModel = false

      // 刷新表格显示
      self.modelTableView.reloadData()

      // 恢复选中状态
      if let ip = self.selectedIndexPath {
        self.modelTableView.selectRow(at: ip, animated: false, scrollPosition: .none)
      }
      if !self.firstLoad {
        self.hideLoadingOverlay()
      }
      self.yoloView.setInferenceFlag(ok: true)

      if success {
        print("Finished loading model: \(modelName)")
        self.currentModelName = modelName
        DispatchQueue.main.async {
          self.labelName.text = processString(modelName)
          self.labelName.textColor = .white
        }

        // 显示成功提示，2秒后隐藏
        self.downloadProgressLabel.text = "Finished loading model \(modelName)"
        self.downloadProgressLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          self.downloadProgressLabel.isHidden = true
          self.downloadProgressLabel.text = ""
        }

      } else {
        print("Failed to load model: \(modelName)")
      }
    }
  }

  /// 将任务名称转换为 YOLOTask 枚举
  private func convertTaskNameToYOLOTask(_ task: String) -> YOLOTask {
    switch task {
    case "Detect": return .detect
    case "Segment": return .segment
    case "Classify": return .classify
    case "Pose": return .pose
    case "OBB": return .obb
    default: return .detect
    }
  }

  // ============================================
  // 📍 IBAction - 与 Storyboard 连接的事件处理
  // ============================================
  
  /// 触发触觉反馈
  /// 📌 @IBAction 表示这个方法可以在 Storyboard 中连接到 UI 事件
  @IBAction func vibrate(_ sender: Any) {
    selection.selectionChanged()
  }

  /// 任务切换事件处理
  /// 📌 当用户切换分段控件时调用
  @IBAction func indexChanged(_ sender: UISegmentedControl) {
    selection.selectionChanged()  // 触觉反馈

    let index = sender.selectedSegmentIndex
    guard tasks.indices.contains(index) else { return }

    let newTask = tasks[index].name

    // 检查该任务是否有可用模型
    if (modelsForTask[newTask]?.isEmpty ?? true) && (remoteModelsInfo[newTask]?.isEmpty ?? true) {
      // 显示警告对话框
      let alert = UIAlertController(
        title: "\(newTask) Models not found",
        message: "Please add or define models for \(newTask).",
        preferredStyle: .alert
      )
      alert.addAction(
        UIAlertAction(
          title: "OK", style: .cancel,
          handler: { _ in
            alert.dismiss(animated: true)
          }))
      self.present(alert, animated: true)

      // 恢复到之前的任务
      if let oldIndex = tasks.firstIndex(where: { $0.name == currentTask }) {
        sender.selectedSegmentIndex = oldIndex
      }
      return
    }

    // 切换任务
    currentTask = newTask
    selectedIndexPath = nil
    reloadModelEntriesAndLoadFirst(for: currentTask)

    // 更新表格背景大小
    tableViewBGView.frame = CGRect(
      x: modelTableView.frame.minX - 1,
      y: modelTableView.frame.minY - 1,
      width: modelTableView.frame.width + 2,
      height: CGFloat(currentModels.count * 30 + 2)
    )
  }

  /// Logo 点击事件 - 打开 Ultralytics 官网
  @objc func logoButton() {
    selection.selectionChanged()
    if let link = URL(string: "https://www.ultralytics.com") {
      UIApplication.shared.open(link)
    }
  }

  // ============================================
  // 📍 表格视图设置
  // ============================================
  
  /// 设置模型选择表格
  private func setupTableView() {
    modelTableView.delegate = self
    modelTableView.dataSource = self
    modelTableView.register(
      ModelTableViewCell.self, forCellReuseIdentifier: ModelTableViewCell.identifier)

    modelTableView.backgroundColor = .clear
    modelTableView.separatorStyle = .none
    modelTableView.isScrollEnabled = false

    // 设置背景视图样式
    tableViewBGView.backgroundColor = .darkGray.withAlphaComponent(0.3)
    tableViewBGView.layer.cornerRadius = 5
    tableViewBGView.clipsToBounds = true

    // 添加到 YOLO 视图
    yoloView.addSubview(tableViewBGView)
    yoloView.addSubview(modelTableView)

    modelTableView.translatesAutoresizingMaskIntoConstraints = false
    tableViewBGView.frame = CGRect(
      x: modelTableView.frame.minX - 1,
      y: modelTableView.frame.minY - 1,
      width: modelTableView.frame.width + 2,
      height: CGFloat(currentModels.count * 30 + 2)
    )
  }

  // ============================================
  // 📍 布局调整
  // ============================================
  
  /// 子视图布局完成时调用
  /// 📌 根据屏幕方向调整布局
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    if view.bounds.width > view.bounds.height {
      // 横屏模式
      focus.isHidden = true
      let tableViewWidth = view.bounds.width * 0.2
      modelTableView.frame = CGRect(
        x: segmentedControl.frame.maxX + 20, y: 20, width: tableViewWidth, height: 200)
      
    } else {
      // 竖屏模式
      focus.isHidden = true
      let tableViewWidth = view.bounds.width * 0.4
      modelTableView.frame = CGRect(
        x: view.bounds.width - tableViewWidth - 8,
        y: segmentedControl.frame.maxY + 25,
        width: tableViewWidth,
        height: 200)
    }

    // 更新背景大小
    tableViewBGView.frame = CGRect(
      x: modelTableView.frame.minX - 1,
      y: modelTableView.frame.minY - 1,
      width: modelTableView.frame.width + 2,
      height: CGFloat(currentModels.count * 30 + 2)
    )
  }

  // ============================================
  // 📍 分享功能
  // ============================================
  
  /// 分享按钮点击事件
  @objc func shareButtonTapped() {
    selection.selectionChanged()
    // 截取当前画面
    yoloView.capturePhoto { [weak self] captured in
      guard let self = self else { return }
      if let image = captured {
        DispatchQueue.main.async {
          // 显示系统分享面板
          let activityViewController = UIActivityViewController(
            activityItems: [image], applicationActivities: nil
          )
          activityViewController.popoverPresentationController?.sourceView = self.View0
          self.present(activityViewController, animated: true, completion: nil)
        }
      } else {
        print("error capturing photo")
      }
    }
  }

}

// ============================================
// 📦 UITableViewDataSource, UITableViewDelegate 扩展
// ============================================
/// 表格视图数据源和代理方法
/// 
/// 📌 学习要点：
/// - DataSource 负责提供数据（有多少行、每行显示什么）
/// - Delegate 负责处理交互（点击事件、行高等）
extension ViewController: UITableViewDataSource, UITableViewDelegate {

  /// 返回表格行数
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return currentModels.count
  }

  /// 返回行高
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 30
  }

  /// 配置每个单元格
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell =
      tableView.dequeueReusableCell(withIdentifier: ModelTableViewCell.identifier, for: indexPath)
      as! ModelTableViewCell
    let entry = currentModels[indexPath.row]

    // 检查远程模型是否已下载
    let isDownloaded =
      entry.isRemote ? ModelCacheManager.shared.isModelDownloaded(key: entry.identifier) : true

    // 格式化模型名称
    let formattedName = processString(entry.displayName)

    // 配置单元格
    cell.configure(with: formattedName, isRemote: entry.isRemote, isDownloaded: isDownloaded)

    return cell
  }

  /// 处理行点击事件
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    selection.selectionChanged()  // 触觉反馈

    selectedIndexPath = indexPath
    let selectedEntry = currentModels[indexPath.row]

    // 加载选中的模型
    loadModel(entry: selectedEntry, forTask: currentTask)
  }

}

// ============================================
// 📦 YOLOViewDelegate 扩展
// ============================================
/// YOLO 视图代理方法，接收检测结果和性能数据
extension ViewController {
  
  /// 性能数据更新回调
  /// - Parameters:
  ///   - view: YOLO 视图
  ///   - fps: 每秒帧数
  ///   - inferenceTime: 单次推理耗时（毫秒）
  func yoloView(_ view: YOLOView, didUpdatePerformance fps: Double, inferenceTime: Double) {
    labelFPS.text = String(format: "%.1f FPS - %.1f ms", fps, inferenceTime)
    labelFPS.textColor = .white
  }

  /// 检测结果回调
  /// - Parameters:
  ///   - view: YOLO 视图
  ///   - result: 检测结果
  func yoloView(_ view: YOLOView, didReceiveResult result: YOLOResult) {
    DispatchQueue.main.async {
      // 可以在这里处理检测结果
      // 例如：显示检测到的对象数量、触发特定行为等
    }
  }

}
