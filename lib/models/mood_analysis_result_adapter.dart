import 'package:hive/hive.dart';
import '../services/ai_service.dart';

class MoodAnalysisResultAdapter extends TypeAdapter<MoodAnalysisResult> {
  @override
  final int typeId = 1;

  @override
  MoodAnalysisResult read(BinaryReader reader) {
    final emotions = List<String>.from(reader.read() as List);
    final advice = reader.read() as String;
    final moodWeights = Map<String, double>.from(reader.read() as Map);

    return MoodAnalysisResult(
      emotions: emotions,
      advice: advice,
      moodWeights: moodWeights,
    );
  }

  @override
  void write(BinaryWriter writer, MoodAnalysisResult obj) {
    writer.write(obj.emotions);
    writer.write(obj.advice);
    writer.write(obj.moodWeights);
  }
}

