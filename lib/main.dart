import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'firebase_options.dart';

// ============================================================
// FLASK SERVER
// ============================================================

const String flaskBaseUrl = 'http://192.168.2.65:5000';

// ============================================================
// FCM BACKGROUND HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('================================');
  print('BACKGROUND NOTIFICATION RECEIVED');
  print('TITLE: ${message.notification?.title}');
  print('BODY: ${message.notification?.body}');
  print('DATA: ${message.data}');
  print('================================');
}

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM background message handler
  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  // FCM initialize
  await _initializeFCM();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

// ============================================================
// SEND FCM TOKEN TO FLASK
// ============================================================

Future<void> sendTokenToFlask({
  required String userId,
  String? token,
}) async {
  try {
    final fcmToken = token ?? await FirebaseMessaging.instance.getToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      print('================================');
      print('FCM TOKEN NAHI MILA');
      print('================================');
      return;
    }

    print('================================');
    print('SENDING FCM TOKEN TO FLASK');
    print('USER ID: $userId');
    print('FCM TOKEN: $fcmToken');
    print('================================');

    final response = await http.post(
      Uri.parse('$flaskBaseUrl/api/save-token'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'fcm_token': fcmToken,
      }),
    );

    print('================================');
    print('FLASK RESPONSE');
    print('STATUS: ${response.statusCode}');
    print('BODY: ${response.body}');
    print('================================');

    if (response.statusCode != 200) {
      print(
        'Flask ne token save/update nahi kiya.',
      );
    }
  } catch (e) {
    print('================================');
    print('FLASK TOKEN ERROR');
    print(e);
    print('================================');
  }
}

// ============================================================
// FCM INITIALIZE
// ============================================================

Future<void> _initializeFCM() async {
  final messaging = FirebaseMessaging.instance;

  // ==========================================================
  // REQUEST NOTIFICATION PERMISSION
  // ==========================================================

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  print('================================');
  print('NOTIFICATION PERMISSION');
  print(settings.authorizationStatus);
  print('================================');

  // ==========================================================
  // FOREGROUND NOTIFICATION SETTINGS
  // ==========================================================

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // ==========================================================
  // GET FCM TOKEN
  // ==========================================================

  try {
    final token = await messaging.getToken();

    print('================================');
    print('FCM TOKEN:');
    print(token);
    print('================================');
  } catch (e) {
    print('================================');
    print('FCM TOKEN ERROR');
    print(e);
    print('================================');
  }

  // ==========================================================
  // FOREGROUND MESSAGE
  // ==========================================================

  FirebaseMessaging.onMessage.listen(
    (RemoteMessage message) {
      print('================================');
      print('FOREGROUND NOTIFICATION RECEIVED');
      print('TITLE: ${message.notification?.title}');
      print('BODY: ${message.notification?.body}');
      print('DATA: ${message.data}');
      print('================================');
    },
  );

  // ==========================================================
  // NOTIFICATION CLICKED
  // ==========================================================

  FirebaseMessaging.onMessageOpenedApp.listen(
    (RemoteMessage message) {
      print('================================');
      print('NOTIFICATION CLICKED');
      print('TITLE: ${message.notification?.title}');
      print('BODY: ${message.notification?.body}');
      print('DATA: ${message.data}');
      print('================================');
    },
  );

  // ==========================================================
  // APP OPENED FROM TERMINATED STATE
  // ==========================================================

  try {
    final initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      print('================================');
      print('APP OPENED FROM NOTIFICATION');
      print(
        'TITLE: ${initialMessage.notification?.title}',
      );
      print(
        'BODY: ${initialMessage.notification?.body}',
      );
      print(
        'DATA: ${initialMessage.data}',
      );
      print('================================');
    }
  } catch (e) {
    print('================================');
    print('INITIAL MESSAGE ERROR');
    print(e);
    print('================================');
  }

  // ==========================================================
  // TOKEN REFRESH
  // ==========================================================

  FirebaseMessaging.instance.onTokenRefresh.listen(
    (newToken) async {
      print('================================');
      print('NEW FCM TOKEN:');
      print(newToken);
      print('================================');

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await sendTokenToFlask(
          userId: user.uid,
          token: newToken,
        );
      } else {
        print(
          'User login nahi hai, new token Flask par nahi bheja.',
        );
      }
    },
  );
}

// ============================================================
// SIGNUP DATA
// ============================================================

class SignupData {
  String name = '';
  String email = '';
  String phone = '';
  String dob = '';

  String address = '';
  String city = '';
  String state = '';
  String pin = '';
  String postOffice = '';

  double? latitude;
  double? longitude;
}

// ============================================================
// APP
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signup App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.blue,
              width: 2,
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

// ============================================================
// COMMON BUTTON
// ============================================================

class FullWidthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const FullWidthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ============================================================
// LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email aur password enter karo',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ======================================================
      // LOGIN SUCCESS
      // SEND FCM TOKEN TO FLASK
      // ======================================================

      if (credential.user != null) {
        await sendTokenToFlask(
          userId: credential.user!.uid,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login fail ho gaya';

      if (e.code == 'user-not-found') {
        message = 'Is email se koi account nahi mila';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email ya password galat hai';
      } else if (e.code == 'invalid-email') {
        message = 'Valid email enter karo';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Agnize informatics',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FullWidthButton(
                      text: 'Login',
                      isLoading: isLoading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Create Account',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// CREATE ACCOUNT
// ============================================================

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    dobController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectDob() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime(2000, 1, 1),
    );

    if (picked != null) {
      dobController.text = '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
    }
  }

  Future<void> _continue() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final dob = dobController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        dob.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sabhi fields fill karo',
          ),
        ),
      );
      return;
    }

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '10 digit mobile number enter karo',
          ),
        ),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Valid email enter karo',
          ),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password kam se kam 6 characters ka rakho',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      // Email verification
      await credential.user?.sendEmailVerification();

      final signupData = SignupData();

      signupData.name = name;
      signupData.email = email;
      signupData.phone = phone;
      signupData.dob = dob;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account bana diya. Verification email bhej diya hai.',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(
            signupData: signupData,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Signup fail ho gaya';

      if (e.code == 'email-already-in-use') {
        message = 'Ye email pehle se registered hai';
      } else if (e.code == 'weak-password') {
        message = 'Password kam se kam 6 characters ka rakho';
      } else if (e.code == 'invalid-email') {
        message = 'Valid email enter karo';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dobController,
                readOnly: true,
                onTap: _selectDob,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: Icon(
                    Icons.calendar_month,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              FullWidthButton(
                text: 'Continue',
                isLoading: isSubmitting,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMAIL VERIFICATION
// ============================================================

class EmailVerificationPage extends StatefulWidget {
  final SignupData signupData;

  const EmailVerificationPage({
    super.key,
    required this.signupData,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool isChecking = false;
  bool isResending = false;

  Future<void> _resendVerificationEmail() async {
    if (isResending) return;

    setState(() {
      isResending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'User signed in nahi hai',
        );
      }

      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email dobara bhej diya hai.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Email bhejne me error hua',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  Future<void> _checkVerification() async {
    if (isChecking) return;

    setState(() {
      isChecking = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'User signed in nahi hai',
        );
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser?.emailVerified != true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pehle email me verification link par click karo.',
            ),
          ),
        );

        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddressPage(
            signupData: widget.signupData,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Verification check nahi ho paya',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Email Verification',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.mark_email_read,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Verification link '
                '${widget.signupData.email} '
                'par bheja gaya hai.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 35),
              FullWidthButton(
                text: 'I Have Verified My Email',
                isLoading: isChecking,
                onPressed: _checkVerification,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isResending ? null : _resendVerificationEmail,
                child: Text(
                  isResending ? 'Sending...' : 'Resend Verification Email',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Inbox ke saath Spam/Junk folder bhi check karo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADDRESS PAGE
// ============================================================

class AddressPage extends StatefulWidget {
  final SignupData signupData;

  const AddressPage({
    super.key,
    required this.signupData,
  });

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final addressController = TextEditingController();

  final cityController = TextEditingController();

  final stateController = TextEditingController();

  final pinController = TextEditingController();

  String postOfficeName = '';
  bool isLoadingPin = false;

  @override
  void initState() {
    super.initState();

    pinController.addListener(
      _pinChanged,
    );
  }

  @override
  void dispose() {
    pinController.removeListener(
      _pinChanged,
    );

    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pinController.dispose();

    super.dispose();
  }

  void _pinChanged() {
    final pin = pinController.text.trim();

    if (pin.length == 6 && !isLoadingPin) {
      _lookupPin(pin);
    }
  }

  Future<void> _lookupPin(
    String pin,
  ) async {
    setState(() {
      isLoadingPin = true;
      postOfficeName = '';
    });

    try {
      final uri = Uri.parse(
        'https://api.postalpincode.in/pincode/$pin',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('API error');
      }

      final List<dynamic> result = jsonDecode(response.body);

      if (result.isEmpty) {
        throw Exception('No result');
      }

      final firstResult = Map<String, dynamic>.from(
        result[0],
      );

      final List<dynamic> postOffices = firstResult['PostOffice'] ?? [];

      if (postOffices.isEmpty) {
        throw Exception('PIN not found');
      }

      final postOfficeData = Map<String, dynamic>.from(
        postOffices[0],
      );

      final city = postOfficeData['District']?.toString() ?? '';

      final state = postOfficeData['State']?.toString() ?? '';

      final postOffice = postOfficeData['Name']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        cityController.text = city;
        stateController.text = state;
        postOfficeName = postOffice;
        isLoadingPin = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingPin = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PIN code nahi mila. Please check PIN.',
          ),
        ),
      );
    }
  }

  void _saveAddress() {
    final address = addressController.text.trim();

    final city = cityController.text.trim();

    final state = stateController.text.trim();

    final pin = pinController.text.trim();

    if (address.isEmpty || city.isEmpty || state.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete address fill karo',
          ),
        ),
      );
      return;
    }

    widget.signupData.address = address;

    widget.signupData.city = city;

    widget.signupData.state = state;

    widget.signupData.pin = pin;

    widget.signupData.postOffice = postOfficeName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurrentLocationPage(
          signupData: widget.signupData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Your Address',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: addressController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'House / Street Address',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.home),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'PIN Code',
                  prefixIcon: const Icon(
                    Icons.pin_drop,
                  ),
                  counterText: '',
                  suffixIcon: isLoadingPin
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cityController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'City / District',
                  prefixIcon: Icon(
                    Icons.location_city,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'State',
                  prefixIcon: Icon(Icons.map),
                ),
              ),
              if (postOfficeName.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_post_office,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Post Office: '
                          '$postOfficeName',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              FullWidthButton(
                text: 'Save Address',
                onPressed: _saveAddress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CURRENT LOCATION PAGE
// ============================================================

class CurrentLocationPage extends StatefulWidget {
  final SignupData signupData;

  const CurrentLocationPage({
    super.key,
    required this.signupData,
  });

  @override
  State<CurrentLocationPage> createState() => _CurrentLocationPageState();
}

class _CurrentLocationPageState extends State<CurrentLocationPage> {
  final MapController mapController = MapController();

  LatLng selectedLocation = const LatLng(
    28.6139,
    77.2090,
  );

  bool hasSelectedLocation = false;

  bool isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone ka Location/GPS ON karo',
            ),
          ),
        );

        await Geolocator.openLocationSettings();

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission allow karo',
            ),
          ),
        );

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        selectedLocation = location;
        hasSelectedLocation = true;
        isLoading = false;
      });

      mapController.move(
        location,
        17,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location error: $e',
          ),
        ),
      );
    }
  }

  void _onMapTap(
    TapPosition tapPosition,
    LatLng latLng,
  ) {
    setState(() {
      selectedLocation = latLng;
      hasSelectedLocation = true;
    });
  }

  void _continue() {
    if (!hasSelectedLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Map par location select karo',
          ),
        ),
      );
      return;
    }

    widget.signupData.latitude = selectedLocation.latitude;

    widget.signupData.longitude = selectedLocation.longitude;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSubmitPage(
          signupData: widget.signupData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Current Location',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: selectedLocation,
                      initialZoom: 12,
                      onTap: _onMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/'
                            '{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.signup_firebase_new',
                      ),
                      if (hasSelectedLocation)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: selectedLocation,
                              width: 60,
                              height: 60,
                              child: const Icon(
                                Icons.location_pin,
                                size: 50,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 15,
                    top: 15,
                    child: FloatingActionButton(
                      heroTag: 'locationButton',
                      onPressed: isLoading ? null : _getCurrentLocation,
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.my_location,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withOpacity(0.08),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (hasSelectedLocation)
                    Row(
                      children: [
                        Expanded(
                          child: _CoordinateCard(
                            title: 'Latitude',
                            value: selectedLocation.latitude.toStringAsFixed(6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CoordinateCard(
                            title: 'Longitude',
                            value:
                                selectedLocation.longitude.toStringAsFixed(6),
                          ),
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: Text(
                        'Map par kahin bhi tap karke '
                        'location select karo',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _continue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// COORDINATE CARD
// ============================================================

class _CoordinateCard extends StatelessWidget {
  final String title;
  final String value;

  const _CoordinateCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REVIEW & SUBMIT
// ============================================================

class ReviewSubmitPage extends StatefulWidget {
  final SignupData signupData;

  const ReviewSubmitPage({
    super.key,
    required this.signupData,
  });

  @override
  State<ReviewSubmitPage> createState() => _ReviewSubmitPageState();
}

class _ReviewSubmitPageState extends State<ReviewSubmitPage> {
  bool isSubmitting = false;

  Widget _info(
    String title,
    String value,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final data = widget.signupData;

      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception(
          'User signed in nahi hai',
        );
      }

      // ======================================================
      // GET FCM TOKEN
      // ======================================================

      final fcmToken = await FirebaseMessaging.instance.getToken();

      print(
        '================================',
      );
      print(
        'SUBMIT FCM TOKEN: $fcmToken',
      );
      print(
        '================================',
      );

      // ======================================================
      // SAVE USER + FCM TOKEN TO FIRESTORE
      // ======================================================

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': data.name,
        'email': data.email,
        'phone': data.phone,
        'dob': data.dob,
        'address': data.address,
        'city': data.city,
        'state': data.state,
        'pin': data.pin,
        'postOffice': data.postOffice,
        'latitude': data.latitude,
        'longitude': data.longitude,

        // FCM token
        'fcmToken': fcmToken,

        'createdAt': FieldValue.serverTimestamp(),
      });

      // ======================================================
      // SEND FCM TOKEN TO FLASK
      // ======================================================

      await sendTokenToFlask(
        userId: uid,
        token: fcmToken,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text(
              'Your account is created in '
              'Agnize Informatics',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();

                  Navigator.of(
                    context,
                  ).popUntil(
                    (route) => route.isFirst,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save nahi ho paya: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latitude = widget.signupData.latitude?.toStringAsFixed(6) ?? '';

    final longitude = widget.signupData.longitude?.toStringAsFixed(6) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review & Submit',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Review Your Details',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _info(
                'Name',
                widget.signupData.name,
              ),
              _info(
                'Email',
                widget.signupData.email,
              ),
              _info(
                'Phone',
                widget.signupData.phone,
              ),
              _info(
                'Date of Birth',
                widget.signupData.dob,
              ),
              const SizedBox(height: 10),
              const Text(
                'Address',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _info(
                'Address',
                widget.signupData.address,
              ),
              _info(
                'City / District',
                widget.signupData.city,
              ),
              _info(
                'State',
                widget.signupData.state,
              ),
              _info(
                'PIN',
                widget.signupData.pin,
              ),
              _info(
                'Post Office',
                widget.signupData.postOffice,
              ),
              const SizedBox(height: 10),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _info(
                'Latitude',
                latitude,
              ),
              _info(
                'Longitude',
                longitude,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, '
          '${user?.displayName ?? user?.email ?? ''}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
