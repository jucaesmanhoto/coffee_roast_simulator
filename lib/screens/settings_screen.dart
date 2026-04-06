import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/services.dart';

class SettingsScreen extends StatefulWidget {
  final Coffee initialCoffee;
  final RoasterSettings initialRoasterSettings;

  const SettingsScreen({
    super.key,
    required this.initialCoffee,
    required this.initialRoasterSettings,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controladores para os campos de texto
  late TextEditingController _varietyController;
  late TextEditingController _regionController;
  late TextEditingController _altitudeController;
  late TextEditingController _densityController;
  late TextEditingController _moistureController;

  late TextEditingController _batchSizeController;
  late TextEditingController _chargeTempController;
  late TextEditingController _initialHeatController;
  late TextEditingController _initialAirflowController;
  late TextEditingController _initialDrumSpeedController;
  late TextEditingController _timeScaleController;

  String _selectedRoaster = 'Kaleido M10';

  @override
  void initState() {
    super.initState();
    // Inicializa os controladores com os valores atuais
    _varietyController = TextEditingController(text: widget.initialCoffee.variety);
    _regionController = TextEditingController(text: widget.initialCoffee.region);
    _altitudeController = TextEditingController(text: widget.initialCoffee.altitude.toString());
    _densityController = TextEditingController(text: widget.initialCoffee.density.toString());
    _moistureController = TextEditingController(text: widget.initialCoffee.currentMoisture.toString());

    _batchSizeController = TextEditingController(text: widget.initialRoasterSettings.batchSizeGrams.toString());
    _chargeTempController = TextEditingController(text: widget.initialRoasterSettings.chargeTemp.toString());
    _initialHeatController = TextEditingController(text: widget.initialRoasterSettings.initialHeat.toString());
    _initialAirflowController = TextEditingController(text: widget.initialRoasterSettings.initialAirflow.toString());
    _initialDrumSpeedController = TextEditingController(text: widget.initialRoasterSettings.initialDrumSpeed.toString());
    _timeScaleController = TextEditingController(text: widget.initialRoasterSettings.timeScale.toString());
    _selectedRoaster = widget.initialRoasterSettings.model;
  }

  @override
  void dispose() {
    // Descarta todos os controladores
    _varietyController.dispose();
    _regionController.dispose();
    _altitudeController.dispose();
    _densityController.dispose();
    _moistureController.dispose();
    _batchSizeController.dispose();
    _chargeTempController.dispose();
    _initialHeatController.dispose();
    _initialAirflowController.dispose();
    _initialDrumSpeedController.dispose();
    _timeScaleController.dispose();
    super.dispose();
  }

  void _saveAndReturn() {
    final newCoffee = Coffee(
      variety: _varietyController.text,
      region: _regionController.text,
      altitude: int.tryParse(_altitudeController.text) ?? 1150,
      density: double.tryParse(_densityController.text) ?? 0.7,
      initialMoisture: double.tryParse(_moistureController.text) ?? 11.5,
    );

    final newRoasterSettings = RoasterSettings(
      model: _selectedRoaster,
      batchSizeGrams: double.tryParse(_batchSizeController.text) ?? 600.0,
      chargeTemp: double.tryParse(_chargeTempController.text) ?? 206.0,
      initialHeat: double.tryParse(_initialHeatController.text) ?? 95.0,
      initialAirflow: double.tryParse(_initialAirflowController.text) ?? 25.0,
      initialDrumSpeed: double.tryParse(_initialDrumSpeedController.text) ?? 70.0,
      timeScale: double.tryParse(_timeScaleController.text) ?? 5.0,
    );

    Navigator.pop(context, {'coffee': newCoffee, 'roasterSettings': newRoasterSettings});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('CONFIGURAÇÕES', style: GoogleFonts.oswald(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [Tab(text: 'CAFÉ'), Tab(text: 'TORRADOR')],
            indicatorColor: Colors.orangeAccent,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          children: [
            _buildCoffeeTab(),
            _buildRoasterTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveAndReturn,
          label: const Text('SALVAR E APLICAR'),
          icon: const Icon(Icons.save),
          backgroundColor: Colors.orangeAccent,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.orangeAccent),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildCoffeeTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 80),
          child: Column(
            children: [
              _buildTextField(_varietyController, 'Variedade'),
              _buildTextField(_regionController, 'Região'),
              _buildTextField(_altitudeController, 'Altitude (m)', keyboardType: TextInputType.number),
              _buildTextField(_densityController, 'Densidade (g/mL)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _buildTextField(_moistureController, 'Umidade (%)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoasterTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 80),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedRoaster,
                items: ['Kaleido M10'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRoaster = newValue!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Modelo do Torrador',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(_batchSizeController, 'Massa de Café (g)', keyboardType: TextInputType.number),
              _buildTextField(_chargeTempController, 'Temperatura de Carga (°C)', keyboardType: TextInputType.number),
              _buildTextField(_initialHeatController, 'Potência Inicial (%)', keyboardType: TextInputType.number),
              _buildTextField(_initialAirflowController, 'Fluxo de Ar Inicial (%)', keyboardType: TextInputType.number),
              _buildTextField(_initialDrumSpeedController, 'Rotação do Tambor Inicial (%)', keyboardType: TextInputType.number),
              const Divider(height: 32),
              Text('Configurações de Simulação', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildTextField(_timeScaleController, 'Aceleração do Tempo (ex: 10 para 10x)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
      ),
    );
  }
}
