import 'package:flutter/material.dart';
import 'package:medical/models/doctor_model.dart';
import 'package:medical/services/api_service.dart';

class DoctorSelectionScreen extends StatefulWidget {
  final int? currentDoctorId;
  const DoctorSelectionScreen({super.key, this.currentDoctorId});

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  List<DoctorModel> _doctors = [];
  List<DoctorModel> _filteredDoctors = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  DoctorModel? _selectedDoctor;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final doctorsData = await ApiService.getDoctors();
      final doctors = doctorsData
          .map((json) => DoctorModel.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _doctors = doctors;
          _filteredDoctors = doctors;
          _isLoading = false;

          // Set current doctor if available
          if (widget.currentDoctorId != null) {
            _selectedDoctor = doctors.firstWhere(
              (doctor) => doctor.id == widget.currentDoctorId,
              orElse: () => DoctorModel(
                id: 0,
                name: 'Select Doctor',
                email: '',
                phoneNumber: '',
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterDoctors(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredDoctors = _doctors;
      } else {
        _filteredDoctors = _doctors
            .where(
              (doctor) =>
                  doctor.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _refresh() async {
    await _loadDoctors();
  }

  Future<void> _saveDoctorSelection() async {
    if (_selectedDoctor == null || _selectedDoctor!.id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      await ApiService.updateUserDoctor(_selectedDoctor!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, _selectedDoctor);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign doctor: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateDoctorDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Doctor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Doctor Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await ApiService.createDoctor(
                  name: name,
                  email: email,
                  phoneNumber: phone,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _refresh(); // Refresh the doctor list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Doctor created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create doctor: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Doctor'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showCreateDoctorDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add New Doctor',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading doctors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: _filterDoctors,
                    decoration: InputDecoration(
                      hintText: 'Search doctors...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Doctor list
                Expanded(
                  child: _filteredDoctors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No doctors available'
                                    : 'No doctors found for "$_searchQuery"',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add a new doctor',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredDoctors.length,
                          itemBuilder: (context, index) {
                            final doctor = _filteredDoctors[index];
                            final isSelected = _selectedDoctor?.id == doctor.id;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              color: isSelected
                                  ? const Color(0xFF1565C0).withOpacity(0.1)
                                  : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? const Color(0xFF1565C0)
                                      : const Color(0xFF1565C0),
                                  child: Text(
                                    doctor.name.isNotEmpty
                                        ? doctor.name[0].toUpperCase()
                                        : 'D',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  doctor.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isSelected
                                        ? const Color(0xFF1565C0)
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(doctor.email),
                                    Text(doctor.phoneNumber),
                                  ],
                                ),
                                trailing: Radio<DoctorModel>(
                                  value: doctor,
                                  groupValue: _selectedDoctor,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDoctor = value;
                                    });
                                  },
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedDoctor = doctor;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedDoctor != null
          ? Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _saveDoctorSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Assign Doctor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          : null,
    );
  }
}
