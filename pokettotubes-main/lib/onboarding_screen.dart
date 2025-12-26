import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _onNextPressed() {
    if (_currentPage == 0) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Onboarding finished, navigate to login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDADBDC), // Updated background color
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: const [
                OnboardingPage1(),
                OnboardingPage2(),
              ],
            ),
          ),
          // Navigation and indicators
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 40.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      height: 10,
                      width: 10,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54),
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? const Color(0xFFEB8837)
                            : Colors.white,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _onNextPressed,
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- ONBOARDING PAGE 1: TRACKING ---
class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top orange container
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFFEB8837), // Updated color
            child: const Center(
              child: Text(
                'Welcome To Poketto, ' 
                    'Your Expense Manager',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black, // Updated text color
                  fontSize: 22, // Updated font size
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cabin',
                ),
              ),
            ),
          ),
        ),
        // Bottom grey container with content
        Expanded(
          flex: 7,
          child: Container(
            clipBehavior: Clip.antiAlias, // ADDED THIS LINE TO FIX THE RADIUS
            decoration: const BoxDecoration(
              color: Color(0xFFDADBDC), // Updated color
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(200), // Updated radius
                topRight: Radius.circular(200), // Updated radius
              ),
            ),
            // We use a second container to position it correctly relative to the top one
            child: Transform.translate(
              offset: const Offset(0, -20), // Pulls the content up less
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Illustration
                  Container(
                    height: 280, // Increased size
                    width: 280, // Increased size
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/cat_coins.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- ONBOARDING PAGE 2: LITERACY ---
class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top orange container
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFFEB8837), // Updated color
            child: const Center(
              child: Text(
                '¿Are You Ready To Take Control Of Your Finances?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black, // Updated text color
                  fontSize: 22, // Updated font size
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cabin',
                ),
              ),
            ),
          ),
        ),
        // Bottom grey container with content
        Expanded(
          flex: 7,
          child: Container(
            clipBehavior: Clip.antiAlias, // ADDED THIS LINE TO FIX THE RADIUS
            decoration: const BoxDecoration(
              color: Color(0xFFDADBDC), // Updated color
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(80), // Updated radius
                topRight: Radius.circular(80), // Updated radius
              ),
            ),
            child: Transform.translate(
              offset: const Offset(0, -20), // Pulls the content up less
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Illustration
                  Container(
                    height: 280, // Increased size
                    width: 280, // Increased size
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/cat_shops.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
