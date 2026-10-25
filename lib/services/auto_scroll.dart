/// Velocidades da rolagem automática do leitor, em pixels por segundo.
const List<double> autoScrollSpeeds = [8, 12, 16, 22, 30, 40, 52, 68, 90, 120];

/// Posição (1…n) da velocidade mais próxima de [v], para mostrar ao usuário.
int autoScrollLevel(double v) {
  var best = 0;
  for (var i = 1; i < autoScrollSpeeds.length; i++) {
    if ((autoScrollSpeeds[i] - v).abs() < (autoScrollSpeeds[best] - v).abs()) best = i;
  }
  return best + 1;
}

/// Velocidade um nível acima ([step] = 1) ou abaixo ([step] = -1).
double autoScrollStep(double v, int step) =>
    autoScrollSpeeds[(autoScrollLevel(v) - 1 + step).clamp(0, autoScrollSpeeds.length - 1)];
