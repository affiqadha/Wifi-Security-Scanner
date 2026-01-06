import 'package:flutter/material.dart';

class BackgroundPattern extends StatelessWidget {
  final Widget child;
  
  const BackgroundPattern({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      // Make sure the container takes the full size available
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        image: DecorationImage(
          image: AssetImage(
            isDarkMode 
                ? 'assets/pattern_dark.png' 
                : 'assets/pattern_light.png'
          ),
          repeat: ImageRepeat.repeat,
          opacity: 0.05,
        ),
      ),
      child: child,
    );
  }
}