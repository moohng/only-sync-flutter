import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late MobileScannerController controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isProcessing) return; // 如果正在处理中，直接返回
              _isProcessing = true;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                print('扫描的二维码信息：${barcodes.first.rawValue}');
                Get.back(result: barcodes.first.rawValue);
              }

              // 设置一个延时，比如1秒后才能处理下一次扫描
              Future.delayed(const Duration(seconds: 1), () {
                _isProcessing = false;
              });
            },
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _getErrorMessage(error.errorCode),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
          // 扫描框
          CustomPaint(
            painter: ScannerOverlay(),
            child: Container(),
          ),
          Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).size.width * 1.15,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '将二维码放入框内即可自动扫描',
                    style: TextStyle(color: Color(0xb3ffffff)),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, child) {
                      return IconButton(
                        onPressed: () {
                          controller.toggleTorch();
                        },
                        icon: state.torchState == TorchState.on
                            ? const Icon(Icons.lightbulb)
                            : const Icon(Icons.lightbulb_outline),
                        style: ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(
                            state.torchState == TorchState.on ? const Color(0xffffffff) : const Color(0x80ffffff),
                          ),
                          iconColor: WidgetStatePropertyAll(
                            state.torchState == TorchState.on ? const Color(0xffffffff) : const Color(0x80ffffff),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              )),
        ],
      ),
    );
  }

  String _getErrorMessage(MobileScannerErrorCode errorCode) {
    switch (errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return '请授予相机权限以使用扫描功能';
      case MobileScannerErrorCode.unsupported:
        return '此设备不支持扫描功能';
      default:
        return '扫描器初始化失败，请检查相机权限';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// 自定义扫描框绘制
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 4;

    // 绘制半透明背景
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRect(Rect.fromLTWH(
            scanAreaLeft,
            scanAreaTop,
            scanAreaSize,
            scanAreaSize,
          )),
      ),
      paint,
    );

    // 绘制扫描框边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(
        scanAreaLeft,
        scanAreaTop,
        scanAreaSize,
        scanAreaSize,
      ),
      borderPaint,
    );

    // 绘制角标
    final cornerSize = scanAreaSize * 0.1;
    final cornerPaint = Paint()
      ..color = Theme.of(Get.context!).primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // 左上角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft, scanAreaTop + cornerSize)
        ..lineTo(scanAreaLeft, scanAreaTop)
        ..lineTo(scanAreaLeft + cornerSize, scanAreaTop),
      cornerPaint,
    );

    // 右上角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft + scanAreaSize - cornerSize, scanAreaTop)
        ..lineTo(scanAreaLeft + scanAreaSize, scanAreaTop)
        ..lineTo(scanAreaLeft + scanAreaSize, scanAreaTop + cornerSize),
      cornerPaint,
    );

    // 右下角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerSize)
        ..lineTo(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize)
        ..lineTo(scanAreaLeft + scanAreaSize - cornerSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // 左下角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft + cornerSize, scanAreaTop + scanAreaSize)
        ..lineTo(scanAreaLeft, scanAreaTop + scanAreaSize)
        ..lineTo(scanAreaLeft, scanAreaTop + scanAreaSize - cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
