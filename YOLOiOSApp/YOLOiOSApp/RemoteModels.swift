// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  ========================================
//  ☁️ RemoteModels.swift - 远程模型配置
//  ========================================
//
//  这个文件定义了可从网络下载的 YOLO 模型列表
//
//  📚 学习要点：
//  1. 常量定义和使用
//  2. URL 构造
//  3. 字典（Dictionary）数据结构
//  4. 元组（Tuple）的使用
//
//  📌 YOLO 模型命名规则：
//  - yolo11n: YOLO v11, nano 版本（最小最快）
//  - yolo11s: YOLO v11, small 版本
//  - yolo11m: YOLO v11, medium 版本
//  - yolo11l: YOLO v11, large 版本
//  - yolo11x: YOLO v11, extra-large 版本（最大最准）
//  
//  - -seg: 语义分割模型（Segmentation）
//  - -cls: 图像分类模型（Classification）
//  - -pose: 姿态估计模型（Pose Estimation）
//  - -obb: 旋转框检测模型（Oriented Bounding Box）
//

import Foundation

// ============================================
// 📍 配置常量
// ============================================
/// 模型下载的基础 URL
/// 📌 模型托管在 GitHub Releases 上
private let baseURL = "https://github.com/ultralytics/yolo-ios-app/releases/download/v8.3.0"

/// 构建模型下载 URL 的辅助函数
/// 
/// 📌 private 表示只在当前文件内可见
/// 
/// - Parameter name: 模型名称（如 "yolo11n"）
/// - Returns: 完整的下载 URL
/// 
/// 示例：
/// - modelURL("yolo11n") → "https://github.com/.../yolo11n.mlpackage.zip"
private func modelURL(_ name: String) -> URL {
  URL(string: "\(baseURL)/\(name).mlpackage.zip")!
}


// ============================================
// 📍 远程模型注册表
// ============================================
/// 可下载的远程模型配置
/// 
/// 📌 数据结构说明：
/// - 键（Key）: 任务名称，如 "Detect", "Segment"
/// - 值（Value）: 元组数组，每个元组包含 (模型名称, 下载URL)
///
/// 📌 public 表示可以被其他模块访问
/// 📌 let 表示常量，不可修改
///
/// 📌 使用示例：
/// ```
/// let detectModels = remoteModelsInfo["Detect"]
/// // 返回: [("yolo11n", URL), ("yolo11s", URL), ...]
/// ```
public let remoteModelsInfo: [String: [(modelName: String, downloadURL: URL)]] = [
  
  // ============================================
  // 🎯 目标检测模型（Detect）
  // ============================================
  // 📌 用途：检测图像中的物体并标注边界框
  // 📌 输出：物体类别 + 矩形边界框
  "Detect": [
    ("yolo11n", modelURL("yolo11n")),  // Nano: ~6MB, 最快
    ("yolo11s", modelURL("yolo11s")),  // Small: ~21MB
    ("yolo11m", modelURL("yolo11m")),  // Medium: ~39MB
    ("yolo11l", modelURL("yolo11l")),  // Large: ~49MB
    ("yolo11x", modelURL("yolo11x")),  // Extra-Large: ~57MB, 最准
  ],
  
  // ============================================
  // 🎨 语义分割模型（Segment）
  // ============================================
  // 📌 用途：对图像中的每个像素进行分类
  // 📌 输出：物体类别 + 像素级分割遮罩
  "Segment": [
    ("yolo11n-seg", modelURL("yolo11n-seg")),
    ("yolo11s-seg", modelURL("yolo11s-seg")),
    ("yolo11m-seg", modelURL("yolo11m-seg")),
    ("yolo11l-seg", modelURL("yolo11l-seg")),
    ("yolo11x-seg", modelURL("yolo11x-seg")),
  ],
  
  // ============================================
  // 🏷️ 图像分类模型（Classify）
  // ============================================
  // 📌 用途：判断整张图像属于哪个类别
  // 📌 输出：图像类别 + 置信度
  "Classify": [
    ("yolo11n-cls", modelURL("yolo11n-cls")),
    ("yolo11s-cls", modelURL("yolo11s-cls")),
    ("yolo11m-cls", modelURL("yolo11m-cls")),
    ("yolo11l-cls", modelURL("yolo11l-cls")),
    ("yolo11x-cls", modelURL("yolo11x-cls")),
  ],
  
  // ============================================
  // 🏃 姿态估计模型（Pose）
  // ============================================
  // 📌 用途：检测人体关键点（骨架）
  // 📌 输出：人体边界框 + 17个关键点坐标
  //    （鼻子、眼睛、耳朵、肩膀、手肘、手腕、臀部、膝盖、脚踝）
  "Pose": [
    ("yolo11n-pose", modelURL("yolo11n-pose")),
    ("yolo11s-pose", modelURL("yolo11s-pose")),
    ("yolo11m-pose", modelURL("yolo11m-pose")),
    ("yolo11l-pose", modelURL("yolo11l-pose")),
    ("yolo11x-pose", modelURL("yolo11x-pose")),
  ],
  
  // ============================================
  // 📐 旋转框检测模型（OBB - Oriented Bounding Box）
  // ============================================
  // 📌 用途：检测带旋转角度的物体（如俯拍的车辆、文档）
  // 📌 输出：物体类别 + 旋转矩形框（支持任意角度）
  // 📌 与普通检测的区别：边界框可以旋转，更紧密地贴合物体
  "OBB": [
    ("yolo11n-obb", modelURL("yolo11n-obb")),
    ("yolo11s-obb", modelURL("yolo11s-obb")),
    ("yolo11m-obb", modelURL("yolo11m-obb")),
    ("yolo11l-obb", modelURL("yolo11l-obb")),
    ("yolo11x-obb", modelURL("yolo11x-obb")),
  ],
]


// ============================================
// 📚 YOLO 模型大小对比（以检测模型为例）
// ============================================
//
// | 模型     | 参数量  | 速度(ms) | 精度(mAP) | 适用场景           |
// |----------|--------|---------|-----------|-------------------|
// | YOLO11n  | ~2.6M  | ~6      | 39.5%     | 移动端实时检测      |
// | YOLO11s  | ~9.4M  | ~10     | 47.0%     | 移动端/边缘设备     |
// | YOLO11m  | ~20M   | ~20     | 51.5%     | 平衡速度和精度      |
// | YOLO11l  | ~25M   | ~30     | 53.4%     | 服务器/高性能设备   |
// | YOLO11x  | ~56M   | ~50     | 54.7%     | 需要最高精度的场景  |
//
// 📌 选择建议：
// - iPhone 实时检测：推荐 yolo11n 或 yolo11s
// - 单张图片分析：可以使用 yolo11m 或更大的模型
// - 模型越大，精度越高，但速度越慢、内存占用越大
