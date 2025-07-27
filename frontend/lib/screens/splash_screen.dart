// // import 'package:flutter/material.dart';
// // import 'package:video_player/video_player.dart';

// // class SplashScreen extends StatefulWidget {
// //   const SplashScreen({super.key});

// //   @override
// //   State<SplashScreen> createState() => _SplashScreenState();
// // }

// // class _SplashScreenState extends State<SplashScreen>
// //     with SingleTickerProviderStateMixin {
// //   late VideoPlayerController _controller;
// //   late AnimationController _fadeController;
// //   late Animation<double> _fadeAnimation;

// //   @override
// //   void initState() {
// //     super.initState();

// //     _controller = VideoPlayerController.asset('assets/intro_video.mp4')
// //       ..initialize().then((_) {
// //         setState(() {});
// //         _controller.play();
// //         _controller.setLooping(false);

// //         _controller.addListener(() {
// //           final isFinished =
// //               _controller.value.position >= _controller.value.duration;

// //           if (isFinished && mounted) {
// //             _fadeController.forward();
// //           }
// //         });
// //       });

// //     _fadeController = AnimationController(
// //       duration: const Duration(milliseconds: 800),
// //       vsync: this,
// //     );

// //     _fadeAnimation = CurvedAnimation(
// //       parent: _fadeController,
// //       curve: Curves.easeInOut,
// //     );

// //     _fadeController.addStatusListener((status) {
// //       if (status == AnimationStatus.completed && mounted) {
// //         Navigator.of(context).pushReplacementNamed('/');
// //       }
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     _fadeController.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.black,
// //       body: Stack(
// //         fit: StackFit.expand,
// //         children: [
// //           Center(
// //             child: _controller.value.isInitialized
// //                 ? AspectRatio(
// //                     aspectRatio: _controller.value.aspectRatio,
// //                     child: VideoPlayer(_controller),
// //                   )
// //                 : const CircularProgressIndicator(),
// //           ),
// //           FadeTransition(
// //             opacity: _fadeAnimation,
// //             child: Container(color: Colors.black),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // lib/screens/splash_screen.dart

// // import 'package:flutter/material.dart';
// // import 'package:video_player/video_player.dart';

// // class SplashScreen extends StatefulWidget {
// //   const SplashScreen({super.key});

// //   @override
// //   State<SplashScreen> createState() => _SplashScreenState();
// // }

// // class _SplashScreenState extends State<SplashScreen> {
// //   late VideoPlayerController _controller;
// //   bool _showWhiteOverlay = false;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _controller = VideoPlayerController.asset('assets/intro_video.mp4')
// //       ..initialize().then((_) {
// //         setState(() {});
// //         _controller.play();
// //       });

// //     _controller.setLooping(false);
// //     _controller.addListener(() {
// //       if (_controller.value.position >= _controller.value.duration) {
// //         if (!_showWhiteOverlay) {
// //           setState(() => _showWhiteOverlay = true);
// //           Future.delayed(const Duration(milliseconds: 800), () {
// //             Navigator.pushReplacementNamed(context, '/');
// //           });
// //         }
// //       }
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.black,
// //       body: Stack(
// //         children: [
// //           Center(
// //             child: _controller.value.isInitialized
// //                 ? FittedBox(
// //                     fit: BoxFit.cover,
// //                     child: SizedBox(
// //                       width: _controller.value.size.width,
// //                       height: _controller.value.size.height,
// //                       child: VideoPlayer(_controller),
// //                     ),
// //                   )
// //                 : const CircularProgressIndicator(),
// //           ),

// //           // 🔥 White fade overlay
// //           AnimatedOpacity(
// //             opacity: _showWhiteOverlay ? 1.0 : 0.0,
// //             duration: const Duration(milliseconds: 700),
// //             child: Container(
// //               color: Colors.white,
// //               width: double.infinity,
// //               height: double.infinity,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// }

// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _showWhiteOverlay = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/intro_video.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.addListener(_checkVideoEnd);
      });
    _controller.setLooping(false);
  }

  void _checkVideoEnd() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (!_navigated && duration != Duration.zero && position >= duration) {
      _navigated = true; // prevent double call
      setState(() => _showWhiteOverlay = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _controller.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
          AnimatedOpacity(
            opacity: _showWhiteOverlay ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}
