// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  ========================================
//  📥 ModelDownloadManager.swift - 模型下载管理器
//  ========================================
//
//  这个文件负责管理机器学习模型的下载、缓存和加载
//
//  📚 学习要点：
//  1. 单例模式（Singleton）的实现和使用
//  2. 文件系统操作（FileManager）
//  3. 网络下载（URLSession）
//  4. Core ML 模型编译和加载
//  5. ZIP 文件解压
//
//  🏗️ 文件结构：
//  - ModelEntry: 模型信息结构体
//  - ModelCacheManager: 模型缓存管理（内存缓存 + 磁盘缓存）
//  - ModelDownloadManager: 模型下载管理
//  - ModelFileManager: 模型文件清理
//

import CoreML          // 📌 Core ML 框架 - 用于加载和运行机器学习模型
import Foundation      // 📌 基础框架 - 提供基本数据类型和系统功能
import ZIPFoundation   // 📌 第三方库 - 用于 ZIP 文件解压

// ============================================
// 📍 全局常量
// ============================================
/// 文档目录路径（应用的私有存储空间）
/// 
/// 📌 iOS 存储位置说明：
/// - Documents: 用户数据，会被 iCloud 备份
/// - Library/Caches: 缓存数据，不会备份，可能被系统清理
/// - tmp: 临时文件，随时可能被清理
private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]


// ============================================
// 📦 ModelEntry - 模型条目结构体
// ============================================
/// 表示一个 YOLO 模型的元数据
/// 
/// 📌 struct vs class:
/// - struct 是值类型，复制时会创建副本
/// - class 是引用类型，复制时只是引用同一个对象
/// - 对于简单的数据容器，推荐使用 struct
struct ModelEntry {
  /// 显示名称（如 "yolo11n"）
  let displayName: String
  
  /// 唯一标识符（用于缓存键）
  let identifier: String
  
  /// 是否为本地 Bundle 中的模型
  let isLocalBundle: Bool
  
  /// 是否为远程模型
  let isRemote: Bool
  
  /// 远程下载 URL（仅远程模型有值）
  let remoteURL: URL?

  /// 初始化方法
  /// - Parameters:
  ///   - displayName: 显示名称
  ///   - identifier: 唯一标识符
  ///   - isLocalBundle: 是否本地模型（默认 false）
  ///   - isRemote: 是否远程模型（默认 false）
  ///   - remoteURL: 远程 URL（默认 nil）
  init(displayName: String, identifier: String, isLocalBundle: Bool = false, isRemote: Bool = false, remoteURL: URL? = nil) {
    self.displayName = displayName
    self.identifier = identifier
    self.isLocalBundle = isLocalBundle
    self.isRemote = isRemote
    self.remoteURL = remoteURL
  }
}


// ============================================
// 📦 ModelCacheManager - 模型缓存管理器
// ============================================
/// 管理模型的内存缓存和磁盘缓存
/// 
/// 📌 单例模式说明：
/// - 确保整个应用只有一个实例
/// - 通过 `ModelCacheManager.shared` 访问
/// - private init() 防止外部创建新实例
///
/// 📌 缓存策略：
/// - 内存缓存：最多保存 3 个编译后的模型
/// - 磁盘缓存：已下载的模型永久保存在 Documents 目录
/// - LRU 算法：最近最少使用的模型会被移出内存缓存
class ModelCacheManager {
  
  /// 单例实例
  /// 📌 static let 确保只初始化一次，且线程安全
  static let shared = ModelCacheManager()
  
  /// 内存中的模型缓存
  /// 📌 字典：键是模型标识符，值是编译后的 MLModel
  var modelCache: [String: MLModel] = [:]
  
  /// 访问顺序记录（用于 LRU 算法）
  /// 📌 最早访问的在数组开头，最近访问的在末尾
  private var accessOrder: [String] = []
  
  /// 缓存容量限制
  private let cacheLimit = 3
  
  /// 当前选中的模型键
  private var currentSelectedModelKey: String?

  /// 私有初始化方法（防止外部创建实例）
  private init() {}

  // ============================================
  // 📍 缓存管理方法
  // ============================================
  
  /// 更新缓存访问顺序
  /// 📌 每次访问模型时调用，将其移到数组末尾
  private func updateAccessOrder(for key: String) {
    // 如果已存在，先移除
    if let index = accessOrder.firstIndex(of: key) {
      accessOrder.remove(at: index)
    }
    // 添加到末尾（表示最近访问）
    accessOrder.append(key)
  }

  /// 获取模型在磁盘上的存储路径
  /// 📌 编译后的模型扩展名为 .mlmodelc
  private func modelURL(for key: String) -> URL {
    documentsDirectory.appendingPathComponent(key).appendingPathExtension("mlmodelc")
  }

  /// 加载 Bundle 中的预置模型
  /// 📌 通常在应用首次启动时调用
  func loadBundledModel() {
    guard let url = getModelFileURL(fileName: "yolov8m"),
          let bundledModel = try? MLModel(contentsOf: url) else {
      print("Failed to load bundled model")
      return
    }
    
    // 添加到内存缓存
    addModelToCache(bundledModel, for: "yolov8m")
    let destinationURL = modelURL(for: "yolov8m")
    
    // 复制到 Documents 目录（如果不存在）
    do {
      if !FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.copyItem(at: url, to: destinationURL)
        print("File copied to documents directory: \(destinationURL.path)")
      }
    } catch {
      print("Error copying file: \(error)")
    }
  }

  /// 加载本地（磁盘）缓存的模型
  /// - Parameters:
  ///   - key: 模型标识符
  ///   - completion: 完成回调，参数为 (模型, 键)
  func loadLocalModel(key: String, completion: @escaping (MLModel?, String) -> Void) {
    // 先检查内存缓存
    if let cachedModel = modelCache[key] {
      updateAccessOrder(for: key)
      completion(cachedModel, key)
      return
    }

    // 检查磁盘缓存
    let localModelURL = modelURL(for: key)
    guard FileManager.default.fileExists(atPath: localModelURL.path) else { return }
    
    do {
      // 从磁盘加载模型
      let model = try MLModel(contentsOf: localModelURL)
      addModelToCache(model, for: key)
      completion(model, key)
    } catch {
      print("Error loading local model: \(error)")
    }
  }

  /// 加载模型（优先使用缓存，否则下载）
  /// - Parameters:
  ///   - fileName: ZIP 文件名
  ///   - remoteURL: 远程下载 URL
  ///   - key: 模型标识符
  ///   - completion: 完成回调
  func loadModel(from fileName: String, remoteURL: URL, key: String, completion: @escaping (MLModel?, String) -> Void) {
    // 1️⃣ 检查内存缓存
    if let cachedModel = modelCache[key] {
      updateAccessOrder(for: key)
      completion(cachedModel, key)
      return
    }

    // 2️⃣ 检查磁盘缓存
    if FileManager.default.fileExists(atPath: modelURL(for: key).path) {
      loadLocalModel(key: key, completion: completion)
    } else {
      // 3️⃣ 需要下载
      ModelDownloadManager.shared.startDownload(url: remoteURL, fileName: fileName, key: key, completion: completion)
    }
  }

  /// 将模型添加到内存缓存
  /// - Parameters:
  ///   - model: Core ML 模型
  ///   - key: 模型标识符
  func addModelToCache(_ model: MLModel, for key: String) {
    // 如果缓存已满，移除最早访问的模型
    if modelCache.count >= cacheLimit {
      let oldKey = accessOrder.removeFirst()
      modelCache.removeValue(forKey: oldKey)
    }
    // 添加新模型
    modelCache[key] = model
    accessOrder.append(key)
  }

  /// 检查模型是否已下载（存在于磁盘）
  func isModelDownloaded(key: String) -> Bool {
    FileManager.default.fileExists(atPath: modelURL(for: key).path)
  }

  /// 优先下载指定模型
  func prioritizeDownload(for fileName: String, completion: @escaping (MLModel?, String) -> Void) {
    ModelDownloadManager.shared.prioritizeDownload(for: fileName, completion: completion)
  }

  /// 设置当前选中的模型键
  func setCurrentSelectedModelKey(_ key: String) { currentSelectedModelKey = key }
  
  /// 获取当前选中的模型键
  func getCurrentSelectedModelKey() -> String? { currentSelectedModelKey }
}


// ============================================
// 📦 ModelDownloadManager - 模型下载管理器
// ============================================
/// 管理模型文件的网络下载
/// 
/// 📌 继承关系：
/// - NSObject: Objective-C 基类，使用 URLSession 代理需要
/// 
/// 📌 URLSession 说明：
/// - iOS 的网络请求框架
/// - 支持后台下载、断点续传
/// - 通过代理（Delegate）接收下载进度和完成回调
class ModelDownloadManager: NSObject {
  
  /// 单例实例
  static let shared = ModelDownloadManager()
  
  /// 下载任务映射表：任务 -> (目标 URL, 模型键)
  private var downloadTasks: [URLSessionDownloadTask: (url: URL, key: String)] = [:]
  
  /// 完成回调映射表：任务 -> 回调闭包
  private var downloadCompletionHandlers: [URLSessionDownloadTask: (MLModel?, String) -> Void] = [:]
  
  /// 当前优先下载的任务
  private var priorityTask: URLSessionDownloadTask?
  
  /// 下载进度回调（0.0 ~ 1.0）
  var progressHandler: ((Double) -> Void)?

  /// 私有初始化方法
  private override init() {}

  // ============================================
  // 📍 私有辅助方法
  // ============================================
  
  /// 完成下载任务并清理
  private func completeTask(_ task: URLSessionDownloadTask, model: MLModel?, key: String) {
    downloadCompletionHandlers[task]?(model, key)
    downloadCompletionHandlers.removeValue(forKey: task)
  }

  /// 创建高优先级下载任务
  private func createPriorityTask(from task: URLSessionDownloadTask, urlKeyPair: (url: URL, key: String), completion: @escaping (MLModel?, String) -> Void) {
    let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    let priorityDownloadTask = session.downloadTask(with: task.originalRequest!)
    priorityDownloadTask.priority = URLSessionTask.highPriority
    downloadTasks[priorityDownloadTask] = urlKeyPair
    downloadCompletionHandlers[priorityDownloadTask] = completion
    priorityTask = priorityDownloadTask
    priorityDownloadTask.resume()
  }

  // ============================================
  // 📍 公开 API
  // ============================================
  
  /// 开始下载模型
  /// - Parameters:
  ///   - url: 远程 URL
  ///   - fileName: 本地文件名
  ///   - key: 模型标识符
  ///   - completion: 完成回调
  func startDownload(url: URL, fileName: String, key: String, completion: @escaping (MLModel?, String) -> Void) {
    // 创建 URLSession（带代理）
    let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    // 创建下载任务
    let downloadTask = session.downloadTask(with: url)
    // 设置目标路径
    let destinationURL = documentsDirectory.appendingPathComponent(fileName)
    // 保存任务信息
    downloadTasks[downloadTask] = (url: destinationURL, key: key)
    downloadCompletionHandlers[downloadTask] = completion
    // 开始下载
    downloadTask.resume()
  }

  /// 将指定文件的下载设为高优先级
  /// 📌 当用户切换选择时，优先下载当前选中的模型
  func prioritizeDownload(for fileName: String, completion: @escaping (MLModel?, String) -> Void) {
    for (task, urlKeyPair) in downloadTasks {
      guard urlKeyPair.url.lastPathComponent.contains(fileName) else { continue }
      
      // 取消当前任务，获取已下载的数据
      task.cancel(byProducingResumeData: { resumeData in
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let priorityDownloadTask: URLSessionDownloadTask
        
        // 如果有已下载的数据，使用断点续传
        if let resumeData = resumeData {
          priorityDownloadTask = session.downloadTask(withResumeData: resumeData)
        } else {
          priorityDownloadTask = session.downloadTask(with: task.originalRequest!)
        }
        
        // 设置高优先级
        priorityDownloadTask.priority = URLSessionTask.highPriority
        self.downloadTasks[priorityDownloadTask] = urlKeyPair
        self.downloadCompletionHandlers[priorityDownloadTask] = completion
        self.priorityTask = priorityDownloadTask
        priorityDownloadTask.resume()
      })
      break
    }
  }

  /// 取消当前下载
  func cancelCurrentDownload() {
    priorityTask?.cancel()
    priorityTask = nil
  }
}


// ============================================
// 📦 URLSessionDownloadDelegate 扩展
// ============================================
/// URLSession 下载代理方法
/// 
/// 📌 这些方法由系统在下载过程中自动调用
extension ModelDownloadManager: URLSessionDownloadDelegate {
  
  /// 下载完成时调用
  /// - Parameters:
  ///   - session: URLSession 实例
  ///   - downloadTask: 下载任务
  ///   - location: 临时文件位置
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    // 获取任务信息
    guard let destinationURL = downloadTasks[downloadTask]?.url,
          let key = downloadTasks[downloadTask]?.key else { return }
    
    do {
      // 1️⃣ 移动 ZIP 文件到目标位置
      let zipURL = destinationURL
      if fileExists(at: zipURL) {
        try FileManager.default.removeItem(at: zipURL)
      }
      try FileManager.default.moveItem(at: location, to: zipURL)
      downloadTasks.removeValue(forKey: downloadTask)
      
      // 2️⃣ 解压到临时目录（避免冲突）
      let tempExtractionURL = documentsDirectory.appendingPathComponent("temp_\(key)")
      if FileManager.default.fileExists(atPath: tempExtractionURL.path) {
        try FileManager.default.removeItem(at: tempExtractionURL)
      }
      
      try unzipSkippingMacOSX(at: zipURL, to: tempExtractionURL)
      
      // 3️⃣ 递归查找模型文件
      func findModelFile(in directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        
        // 先在当前目录查找
        for url in contents {
          if ["mlmodel", "mlpackage"].contains(url.pathExtension) {
            return url
          }
        }
        
        // 再递归搜索子目录
        for url in contents {
          let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
          if resourceValues.isDirectory == true {
            if let found = try findModelFile(in: url) {
              return found
            }
          }
        }
        
        return nil
      }
      
      // 4️⃣ 找到模型文件
      guard let foundModelURL = try findModelFile(in: tempExtractionURL) else {
        throw NSError(domain: "ModelDownload", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model file found in extracted archive"])
      }
      
      // 5️⃣ 编译并加载模型
      loadModel(from: foundModelURL, key: key) { model in
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempExtractionURL)
        try? FileManager.default.removeItem(at: zipURL)
        self.completeTask(downloadTask, model: model, key: key)
      }
    } catch {
      print("Download processing failed: \(error)")
      completeTask(downloadTask, model: nil, key: key)
    }
  }

  /// 编译并加载模型
  /// - Parameters:
  ///   - url: 模型文件 URL
  ///   - key: 模型标识符
  ///   - completion: 完成回调
  private func loadModel(from url: URL, key: String, completion: @escaping (MLModel?) -> Void) {
    // 在后台线程执行（编译模型可能耗时较长）
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // 编译模型（将 .mlmodel/.mlpackage 编译为 .mlmodelc）
        let compiledModelURL = try MLModel.compileModel(at: url)
        // 加载编译后的模型
        let model = try MLModel(contentsOf: compiledModelURL)
        // 保存到永久存储位置
        let localModelURL = documentsDirectory.appendingPathComponent(key).appendingPathExtension("mlmodelc")
        ModelCacheManager.shared.addModelToCache(model, for: key)
        try FileManager.default.moveItem(at: compiledModelURL, to: localModelURL)
        // 在主线程回调
        DispatchQueue.main.async { completion(model) }
      } catch {
        print("Failed to load model: \(error)")
        DispatchQueue.main.async { completion(nil) }
      }
    }
  }

  /// 下载进度更新时调用
  /// - Parameters:
  ///   - bytesWritten: 本次写入的字节数
  ///   - totalBytesWritten: 已下载的总字节数
  ///   - totalBytesExpectedToWrite: 文件总大小
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    // 计算进度（0.0 ~ 1.0）
    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    // 在主线程更新 UI
    DispatchQueue.main.async { self.progressHandler?(progress) }
  }
}


// ============================================
// 📦 ModelFileManager - 模型文件管理器
// ============================================
/// 管理已下载模型文件的清理
class ModelFileManager {
  
  /// 单例实例
  static let shared = ModelFileManager()
  
  private init() {}

  /// 删除所有已下载的模型
  /// 📌 用于清理存储空间或重置应用
  func deleteAllDownloadedModels() {
    do {
      // 获取 Documents 目录下的所有文件
      let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
      // 筛选并删除模型文件
      for fileURL in fileURLs where ["mlmodel", "mlmodelc", "mlpackage"].contains(fileURL.pathExtension) {
        try FileManager.default.removeItem(at: fileURL)
        print("Deleted file: \(fileURL.lastPathComponent)")
      }
    } catch {
      print("Error deleting files: \(error)")
    }
  }
}


// ============================================
// 📍 辅助函数
// ============================================

/// 获取 Bundle 中模型文件的 URL
/// - Parameter fileName: 文件名（不含扩展名）
/// - Returns: 模型文件 URL
func getModelFileURL(fileName: String) -> URL? {
  Bundle.main.url(forResource: fileName, withExtension: "mlmodelc")
}

/// 检查文件是否存在
func fileExists(at url: URL) -> Bool {
  FileManager.default.fileExists(atPath: url.path)
}

/// URL 扩展 - 修改文件扩展名
extension URL {
  /// 将文件扩展名改为新的扩展名
  func changingFileExtension(to newExtension: String) -> URL? {
    var urlString = self.absoluteString
    // 使用正则表达式匹配并替换扩展名
    if let range = urlString.range(of: "\\.[^./]*$", options: .regularExpression) {
      urlString.replaceSubrange(range, with: ".\(newExtension)")
    } else {
      urlString.append(".\(newExtension)")
    }
    return URL(string: urlString)
  }
}

/// 解压 ZIP 文件（跳过 macOS 特有的元数据文件）
/// 
/// 📌 macOS 创建的 ZIP 文件通常包含 __MACOSX 文件夹和 ._ 前缀的文件
/// 这些是 macOS 的资源分支（Resource Fork）文件，在 iOS 上不需要
///
/// - Parameters:
///   - sourceURL: ZIP 文件路径
///   - destinationURL: 解压目标路径
func unzipSkippingMacOSX(at sourceURL: URL, to destinationURL: URL) throws {
  // 打开 ZIP 文件
  let archive = try Archive(url: sourceURL, accessMode: .read)

  // 创建目标目录
  if !FileManager.default.fileExists(atPath: destinationURL.path) {
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
  }

  // 遍历 ZIP 中的每个条目
  for entry in archive {
    // 跳过 macOS 元数据文件
    guard !entry.path.hasPrefix("__MACOSX") && !entry.path.contains("._") else { continue }

    // 计算目标路径
    let entryDestinationURL = destinationURL.appendingPathComponent(entry.path)
    let parentDir = entryDestinationURL.deletingLastPathComponent()
    
    // 创建父目录
    if !FileManager.default.fileExists(atPath: parentDir.path) {
      try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
    }

    // 解压文件
    _ = try archive.extract(entry, to: entryDestinationURL)
  }
}
