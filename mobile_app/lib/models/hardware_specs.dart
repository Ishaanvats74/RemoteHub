class HardwareSpecs {
  final String os;
  final String osVersion;
  final CpuSpecs cpu;
  final RamSpecs ram;
  final List<GpuSpecs> gpus;
  final Map<String, dynamic>? mac;

  const HardwareSpecs({
    required this.os,
    required this.osVersion,
    required this.cpu,
    required this.ram,
    required this.gpus,
    this.mac,
  });

  factory HardwareSpecs.fromJson(Map<String, dynamic> json) {
    List<GpuSpecs> parsedGpus = [];
    final gpuObj = json['gpu'];
    if (gpuObj is Map<String, dynamic> && gpuObj['gpus'] is List) {
      parsedGpus = (gpuObj['gpus'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => GpuSpecs.fromJson(e))
          .toList();
    } else if (json['gpus'] is List) {
      parsedGpus = (json['gpus'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => GpuSpecs.fromJson(e))
          .toList();
    }

    return HardwareSpecs(
      os: json['os']?.toString() ?? 'Unknown OS',
      osVersion: json['os_version']?.toString() ?? '',
      cpu: json['cpu'] is Map<String, dynamic>
          ? CpuSpecs.fromJson(json['cpu'] as Map<String, dynamic>)
          : CpuSpecs.empty(),
      ram: json['ram'] is Map<String, dynamic>
          ? RamSpecs.fromJson(json['ram'] as Map<String, dynamic>)
          : RamSpecs.empty(),
      gpus: parsedGpus,
      mac: json['mac'] is Map<String, dynamic> ? json['mac'] as Map<String, dynamic> : null,
    );
  }

  factory HardwareSpecs.empty() {
    return HardwareSpecs(
      os: 'System',
      osVersion: '',
      cpu: CpuSpecs.empty(),
      ram: RamSpecs.empty(),
      gpus: const [],
    );
  }
}

class CpuSpecs {
  final String brand;
  final int? cores;
  final int? threads;
  final double? frequencyGhz;

  const CpuSpecs({
    required this.brand,
    this.cores,
    this.threads,
    this.frequencyGhz,
  });

  factory CpuSpecs.fromJson(Map<String, dynamic> json) {
    return CpuSpecs(
      brand: json['brand']?.toString() ?? 'Processor',
      cores: json['cores'] is num ? (json['cores'] as num).toInt() : null,
      threads: json['threads'] is num ? (json['threads'] as num).toInt() : null,
      frequencyGhz: json['frequency_ghz'] is num
          ? (json['frequency_ghz'] as num).toDouble()
          : (json['frequency_ghz'] != null
              ? double.tryParse(json['frequency_ghz'].toString())
              : null),
    );
  }

  factory CpuSpecs.empty() => const CpuSpecs(brand: 'Unknown CPU');
}

class RamSpecs {
  final double totalGb;
  final String type;
  final String speed;

  const RamSpecs({
    required this.totalGb,
    required this.type,
    required this.speed,
  });

  factory RamSpecs.fromJson(Map<String, dynamic> json) {
    double total = 0.0;
    if (json['total_gb'] is num) {
      total = (json['total_gb'] as num).toDouble();
    } else if (json['total_gb'] != null) {
      total = double.tryParse(json['total_gb'].toString()) ?? 0.0;
    }

    return RamSpecs(
      totalGb: total,
      type: json['type']?.toString() ?? 'DRAM',
      speed: json['speed']?.toString() ?? '',
    );
  }

  factory RamSpecs.empty() => const RamSpecs(totalGb: 0.0, type: '', speed: '');
}

class GpuSpecs {
  final String name;
  final double? memoryGb;
  final String type;

  const GpuSpecs({
    required this.name,
    this.memoryGb,
    required this.type,
  });

  factory GpuSpecs.fromJson(Map<String, dynamic> json) {
    double? mem;
    if (json['memory_gb'] is num) {
      mem = (json['memory_gb'] as num).toDouble();
    } else if (json['memory_gb'] != null) {
      mem = double.tryParse(json['memory_gb'].toString());
    }

    return GpuSpecs(
      name: json['name']?.toString() ?? 'Graphics Adapter',
      memoryGb: mem,
      type: json['type']?.toString() ?? 'GPU',
    );
  }
}
