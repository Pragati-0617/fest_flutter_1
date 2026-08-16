import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================================
// 1. ABSTRACTION & INTERFACES
// ============================================================================

/// Abstraction: Abstract base class representing any event in the fest.
abstract class FestEvent {
  final String title;
  final String venue;

  FestEvent(this.title, this.venue);

  // Abstract methods enforcing sub-class implementation
  String getEventDetails();
  IconData getIcon();

  // Concrete getter
  String get locationInfo => 'Venue: $venue';
}

/// Interface: Contracts for events that issue certificates.
abstract class Certifiable {
  void generateCertificate(String studentName);
  bool get offersCertificate;
}

// ============================================================================
// 2. MIXINS (Reusable Feature Injection)
// ============================================================================

/// Mixin adding sponsorship and budget handling to events.
mixin SponsorshipRequirement {
  double _budget = 0.0; // Encapsulated private field

  double get budget => _budget;

  void addSponsorship(double amount) {
    if (amount > 0) {
      _budget += amount;
    }
  }

  void allocateExpense(double amount) {
    if (amount <= _budget) {
      _budget -= amount;
    }
  }
}

// ============================================================================
// 3. ENCAPSULATION, INHERITANCE & POLYMORPHISM
// ============================================================================

/// Subclass 1: [TechnicalEvent] extends [FestEvent], uses mixin & interface
class TechnicalEvent extends FestEvent
    with SponsorshipRequirement
    implements Certifiable {
  // Encapsulation: Private members
  int _registrationsCount = 0;
  final int _maxCapacity;

  // Static Member: Tracks total fest registrations across all technical events
  static int totalFestRegistrations = 0;

  // Standard Constructor with super-initializer
  TechnicalEvent(super.title, super.venue, this._maxCapacity);

  // Named Constructor
  TechnicalEvent.codingCompetition(String title)
    : _maxCapacity = 50,
      super(title, 'Lab 302');

  // Factory Constructor: Creates specialized preset events
  factory TechnicalEvent.hackathon() {
    return TechnicalEvent('Ai and Machine Learning', 'Main Auditorium', 100);
  }

  // Getters & Setters for Encapsulated Fields
  int get registrationsCount => _registrationsCount;
  bool get hasCapacity => _registrationsCount < _maxCapacity;

  bool registerStudent() {
    if (_registrationsCount < _maxCapacity) {
      _registrationsCount++;
      totalFestRegistrations++;
      return true;
    }
    return false;
  }

  // Polymorphic Implementation of Abstract Methods
  @override
  String getEventDetails() {
    return 'Tech Event | Slots: $_registrationsCount/$_maxCapacity';
  }

  @override
  IconData getIcon() => Icons.code;

  // Interface Implementation
  @override
  bool get offersCertificate => true;

  @override
  void generateCertificate(String studentName) {
    debugPrint('Certificate generated for $studentName in $title');
  }
}

/// Subclass 2: [CulturalEvent] demonstrating different Polymorphic behavior
class CulturalEvent extends FestEvent implements Certifiable {
  final String category; // e.g., Dance, Music, Drama
  bool _isStageReady = false;

  CulturalEvent(super.title, super.venue, this.category);

  void prepareStage() {
    _isStageReady = true;
  }

  // Polymorphic Overriding
  @override
  String getEventDetails() {
    final status = _isStageReady ? 'Stage Ready' : 'Rehearsals Ongoing';
    return 'Cultural ($category) | Status: $status';
  }

  @override
  IconData getIcon() => Icons.music_note;

  // Interface Implementation
  @override
  bool get offersCertificate => false; // Cultural events might just give trophies

  @override
  void generateCertificate(String studentName) {
    debugPrint('Participation award generated for $studentName');
  }
}

// ============================================================================
// 4. FLUTTER UI INTEGRATION
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  runApp(
    const MaterialApp(
      home: CollegeFestDashboard(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class CollegeFestDashboard extends StatefulWidget {
  const CollegeFestDashboard({super.key});

  @override
  State<CollegeFestDashboard> createState() => _CollegeFestDashboardState();
}

class _CollegeFestDashboardState extends State<CollegeFestDashboard> {
  // Polymorphic List holding base type reference [FestEvent]
  late final List<FestEvent> _festEvents;

  // Navigation state
  String _currentView = 'Home'; // Tracks current view

  // Gallery/Slider state
  late PageController _pageController;
  int _currentImageIndex = 0;
  late List<String> _galleryImages;

  final Uri _collegeLocationUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=KLE+Haveri+BCA+College',
  );
  final Uri _instagramUrl = Uri.parse('https://www.instagram.com/');
  final Uri _facebookUrl = Uri.parse('https://www.facebook.com/');
  final Uri _youtubeUrl = Uri.parse('https://www.youtube.com/');
  final Uri _collegeWebsiteUrl = Uri.parse('https://klehaveri.edu.in/');
  final int _totalParticipants = 1248;

  @override
  void initState() {
    super.initState();
    // Instantiating concrete subclasses via various constructors
    _festEvents = [
      TechnicalEvent.hackathon(), // Factory Constructor
      TechnicalEvent.codingCompetition('Hacakathon'), // Named Constructor
      TechnicalEvent(
        'Flutter Workshop',
        'Class room 502',
        40,
      ), // Standard Constructor
      CulturalEvent(
        'Kannada Orchestor',
        'College Ground',
        'Music',
      ), // Subclass 2
    ];

    // Initialize gallery images
    _galleryImages = [
      'assets/fest_poster.png',
      'assets/images/event_landscape_1.png',
      'assets/images/event_landscape_2.png',
      'assets/images/event_landscape_3.png',
    ];

    // Initialize PageController
    _pageController = PageController(initialPage: 0);

    // Start auto-advance timer
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        _startAutoAdvance(); // Recursively restart timer
      }
    });
  }

  Future<void> _openLocationUrl() async {
    if (!await launchUrl(
      _collegeLocationUrl,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the location link.')),
        );
      }
    }
  }

  Future<void> _openExternalLink(Uri url, String label) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $label.')));
      }
    }
  }

  Widget _buildResponsivePage({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 1200
            ? 1200.0
            : constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KLE Haveri BCA'),
        backgroundColor: const Color.fromARGB(255, 58, 183, 177),
        foregroundColor: const Color.fromARGB(255, 14, 13, 13),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Navigation Menu Bar
          Container(
            color: const Color.fromARGB(255, 220, 245, 244),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildNavigationLinks()),
            ),
          ),
          // Content Area
          Expanded(child: _buildCurrentView()),
        ],
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 220, 245, 244),
        border: Border(
          top: BorderSide(color: Color.fromARGB(255, 58, 183, 177), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Follow Us',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color.fromARGB(255, 20, 20, 20),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Instagram',
            icon: const Icon(
              Icons.camera_alt_rounded,
              color: Color.fromARGB(255, 58, 183, 177),
            ),
            onPressed: () => _openExternalLink(_instagramUrl, 'Instagram'),
          ),
          IconButton(
            tooltip: 'Facebook',
            icon: const Icon(
              Icons.facebook,
              color: Color.fromARGB(255, 58, 183, 177),
            ),
            onPressed: () => _openExternalLink(_facebookUrl, 'Facebook'),
          ),
          IconButton(
            tooltip: 'YouTube',
            icon: const Icon(
              Icons.play_circle_fill,
              color: Color.fromARGB(255, 58, 183, 177),
            ),
            onPressed: () => _openExternalLink(_youtubeUrl, 'YouTube'),
          ),
          IconButton(
            tooltip: 'College Website',
            icon: const Icon(
              Icons.language,
              color: Color.fromARGB(255, 58, 183, 177),
            ),
            onPressed: () =>
                _openExternalLink(_collegeWebsiteUrl, 'college website'),
          ),
        ],
      ),
    );
  }

  /// Build navigation menu items
  List<Widget> _buildNavigationLinks() {
    final menuItems = ['Home', 'Events', 'About', 'Gallery', 'Contact'];
    return menuItems
        .map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _currentView = item;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: _currentView == item
                    ? const Color.fromARGB(255, 58, 183, 177)
                    : Colors.transparent,
                foregroundColor: _currentView == item
                    ? Colors.white
                    : const Color.fromARGB(255, 58, 183, 177),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  /// Build the content view based on current selection
  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'Home':
        return _buildHomeView();
      case 'Events':
        return _buildEventsView();
      case 'About':
        return _buildAboutView();
      case 'Gallery':
        return _buildGalleryView();
      case 'Contact':
        return _buildContactView();
      default:
        return _buildHomeView();
    }
  }

  /// Home View
  Widget _buildHomeView() {
    return _buildResponsivePage(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.15 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index % _galleryImages.length;
                      });
                    },
                    itemCount: _galleryImages.length,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          _galleryImages[index],
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha((0.5 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha((0.5 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _galleryImages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentImageIndex == index ? 10 : 7,
                          height: _currentImageIndex == index ? 10 : 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? const Color.fromARGB(255, 58, 183, 177)
                                : Colors.white.withAlpha((0.7 * 255).round()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoTile(Icons.calendar_today, 'Aug 15, 2026'),
                _buildInfoTile(
                  Icons.location_on,
                  'KLE Haveri BCA College',
                  onTap: _openLocationUrl,
                ),
                _buildInfoTile(
                  Icons.people,
                  '$_totalParticipants Participants',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.event_available, size: 18),
                label: const Text('View Events'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 58, 183, 177),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() => _currentView = 'Events');
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: const Text(
                'KLE INDEPENDENCE DAY\n2026\nDevelop the next generation of freedom—register now to compile our rich heritage and deploy a future of endless possibilities at KLE Haveri.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, {VoidCallback? onTap}) {
    final item = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 232, 248, 247),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color.fromARGB(
            255,
            58,
            183,
            177,
          ).withAlpha((0.35 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color.fromARGB(255, 58, 183, 177), size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return item;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: item,
    );
  }

  /// Events View
  Widget _buildEventsView() {
    return ListView.builder(
      itemCount: _festEvents.length,
      itemBuilder: (context, index) {
        final event = _festEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  /// About View
  Widget _buildAboutView() {
    return _buildResponsivePage(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About College Fest',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'KLE Haveri BCA College Fest is an annual celebration that brings together students, faculty, and industry professionals to showcase talent and innovation.',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 16),
              const Text(
                'Our Events',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Technical Events\n• Cultural Programs\n• Workshops & Seminars\n• Competitions & Hackathons\n• Networking Sessions',
                style: TextStyle(fontSize: 14, height: 1.8),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vision',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'To create a platform where creativity meets technology, fostering innovation and professional growth.',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Gallery View
  Widget _buildGalleryView() {
    return _buildResponsivePage(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gallery',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: List.generate(
                      _galleryImages.length,
                      (index) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade300,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                (0.1 * 255).round(),
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            _galleryImages[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Contact View
  Widget _buildContactView() {
    final emailController = TextEditingController();
    final messageController = TextEditingController();

    return _buildResponsivePage(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact Us',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get in Touch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.email,
                            color: Color.fromARGB(255, 58, 183, 177),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('fest@klehaveri.edu.in')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            color: Color.fromARGB(255, 58, 183, 177),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('+91 9876543210')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color.fromARGB(255, 58, 183, 177),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('KLE Haveri, Karnataka')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Send us a Message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Your Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  hintText: 'Your Message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.message),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Send Message'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Thank you! We will get back to you soon.',
                        ),
                      ),
                    );
                    emailController.clear();
                    messageController.clear();
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Renders UI polymorphically using base class contract [FestEvent]
  Widget _buildEventCard(FestEvent event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => _openEventDetails(event),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 196, 232, 233),
                  child: Icon(
                    event.getIcon(),
                    color: const Color.fromARGB(255, 58, 148, 183),
                  ), // Polymorphic Icon
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${event.locationInfo}\n${event.getEventDetails()}',
                ), // Polymorphic String
                trailing:
                    (event is Certifiable &&
                        (event as Certifiable).offersCertificate)
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.confirmation_num, size: 16),
                        label: const Text(
                          'Voucher',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () =>
                            _promptAndGenerateVoucher(context, event),
                      )
                    : null,
              ),
              const Divider(),

              // Type-specific action triggers
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (event is TechnicalEvent) ...[
                    Text('Budget: Rs${event.budget.toInt()}'), // Mixin property
                    IconButton(
                      icon: const Icon(
                        Icons.attach_money,
                        color: Color.fromARGB(255, 87, 175, 76),
                      ),
                      onPressed: () {
                        setState(() {
                          event.addSponsorship(100.0); // Mixin method
                        });
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Register'),
                      onPressed: () {
                        _showRegistrationDialog(event);
                      },
                    ),
                  ],
                  if (event is CulturalEvent) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.mic, size: 16),
                      label: const Text('Lets start the program'),
                      onPressed: () {
                        setState(() {
                          event.prepareStage();
                        });
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEventDetails(FestEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EventDetailPage(event: event)),
    );
  }

  Future<void> _showRegistrationDialog(TechnicalEvent event) async {
    if (!event.hasCapacity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration full for this event.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final collegeController = TextEditingController();
    final emailController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Register for Event'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Student Name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter student name';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: collegeController,
                        decoration: const InputDecoration(labelText: 'College'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter college name';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter email address';
                          }
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final messenger = ScaffoldMessenger.maybeOf(context);
                          final navigator = Navigator.of(context);

                          setState(() {
                            isSubmitting = true;
                          });

                          final success = await _submitRegistration(
                            event: event,
                            studentName: nameController.text,
                            phoneNumber: phoneController.text,
                            collegeName: collegeController.text,
                            emailAddress: emailController.text,
                          );

                          if (!mounted) return;
                          setState(() {
                            isSubmitting = false;
                          });

                          if (success) {
                            final registered = event.registerStudent();
                            if (registered) {
                              messenger?.showSnackBar(
                                const SnackBar(
                                  content: Text('Registration successful'),
                                ),
                              );
                            } else {
                              messenger?.showSnackBar(
                                const SnackBar(
                                  content: Text('Registration limit reached.'),
                                ),
                              );
                            }
                            // Generate voucher PDF immediately using submitted data
                            await _generateAndShareVoucher({
                              'student_name': nameController.text.trim(),
                              'phone_number': phoneController.text.trim(),
                              'college': collegeController.text.trim(),
                              'email_address': emailController.text.trim(),
                              'event_title': event.title,
                              'event_venue': event.venue,
                              'registered_at': DateTime.now()
                                  .toUtc()
                                  .toIso8601String(),
                            });
                            navigator.pop();
                            setState(() {});
                          } else {
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to submit registration.'),
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _submitRegistration({
    required TechnicalEvent event,
    required String studentName,
    required String phoneNumber,
    required String collegeName,
    required String emailAddress,
  }) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supabase credentials are not configured.'),
        ),
      );
      return false;
    }

    final uri = Uri.parse('$supabaseUrl/rest/v1/registrations');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'return=representation',
      },
      body: jsonEncode({
        'student_name': studentName.trim(),
        'phone_number': phoneNumber.trim(),
        'college': collegeName.trim(),
        'email_address': emailAddress.trim(),
        'event_title': event.title,
        'event_venue': event.venue,
        'event_type': event.runtimeType.toString(),
        'registered_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    return response.statusCode == 201;
  }

  Future<Map<String, dynamic>?> _fetchLatestRegistrationForEmail(
    String email,
    String eventTitle,
  ) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_KEY'];

    if (supabaseUrl == null || supabaseKey == null) return null;

    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/registrations?select=*&event_title=eq.${Uri.encodeComponent(eventTitle)}&email_address=eq.${Uri.encodeComponent(email)}&order=registered_at.desc&limit=1',
    );

    final response = await http.get(
      uri,
      headers: {'apikey': supabaseKey, 'Authorization': 'Bearer $supabaseKey'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      if (list.isNotEmpty) {
        return Map<String, dynamic>.from(list.first as Map);
      }
    }
    return null;
  }

  Future<Uint8List> _createVoucherPdf(Map<String, dynamic> reg) async {
    final doc = pw.Document();

    final student = reg['student_name'] ?? '';
    final eventTitle = reg['event_title'] ?? '';
    final venue = reg['event_venue'] ?? '';
    final college = reg['college'] ?? '';
    final phone = reg['phone_number'] ?? '';
    final email = reg['email_address'] ?? '';
    final registeredAt = reg['registered_at'] ?? '';

    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Event Voucher',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('Name: $student', style: pw.TextStyle(fontSize: 16)),
                pw.Text(
                  'Event: $eventTitle',
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.Text('Venue: $venue', style: pw.TextStyle(fontSize: 16)),
                pw.Text('College: $college', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Phone: $phone', style: pw.TextStyle(fontSize: 14)),
                pw.Text('Email: $email', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Registered At: $registeredAt',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'KLE Haveri BCA',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Voucher ID: ${reg['id'] ?? ''}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  Future<void> _generateAndShareVoucher(Map<String, dynamic> reg) async {
    try {
      final bytes = await _createVoucherPdf(reg);
      final filename = 'voucher_${reg['student_name'] ?? 'ticket'}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate voucher: $e')));
    }
  }

  Future<void> _promptAndGenerateVoucher(
    BuildContext context,
    FestEvent event,
  ) async {
    final emailController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var isLoading = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Enter registered email'),
              content: TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) return;

                          final messenger = ScaffoldMessenger.maybeOf(ctx);
                          final navigator = Navigator.of(ctx);

                          setState(() => isLoading = true);
                          final reg = await _fetchLatestRegistrationForEmail(
                            email,
                            event.title,
                          );
                          setState(() => isLoading = false);
                          if (reg == null) {
                            if (!mounted) return;
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No registration found for that email',
                                ),
                              ),
                            );
                            return;
                          }
                          navigator.pop();
                          await _generateAndShareVoucher(reg);
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Fetch & Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class EventDetailPage extends StatelessWidget {
  final FestEvent event;

  const EventDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        backgroundColor: const Color.fromARGB(255, 58, 183, 177),
        foregroundColor: const Color.fromARGB(255, 14, 13, 13),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.12 * 255).round()),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/fest_poster.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.locationInfo,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.getEventDetails(),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (event is TechnicalEvent) ...[
                    Text(
                      'Budget: Rs${(event as TechnicalEvent).budget.toInt()}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (event is CulturalEvent) ...[
                    Text(
                      'Category: ${(event as CulturalEvent).category}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Certificate: ${(event is Certifiable && (event as Certifiable).offersCertificate) ? 'Available' : 'Not available'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Event Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This page shows details of the selected fest event with a preview image and a summary of what to expect. Use this screen to review the venue, status, and special notes before joining the event.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
