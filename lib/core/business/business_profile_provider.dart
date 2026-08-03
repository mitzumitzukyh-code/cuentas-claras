import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/negocio/data/negocio_repository.dart';
import 'business_presets.dart';
import 'business_profile.dart';

/// Perfil del negocio activo, según su rubro.
///
/// Devuelve un [BusinessProfile] **siempre**, nunca un `AsyncValue`: mientras
/// el negocio carga entrega [perfilPorDefecto]. No hay estado de error posible
/// —un rubro desconocido ya cae en `Rubro.otro` al leer el documento— así que
/// esto no puede tumbar la app ni dejar una pantalla en blanco.
final businessProfileProvider = Provider<BusinessProfile>((ref) {
  final negocio = ref.watch(negocioActivoProvider).valueOrNull;
  if (negocio == null) return perfilPorDefecto;
  return perfilDe(negocio.rubro);
});

/// Vocabulario del negocio activo. Atajo para no escribir el `watch` completo
/// cada vez que hay que rotular un botón.
final vocabProvider = Provider<Vocabulary>(
  (ref) => ref.watch(businessProfileProvider).vocab,
);

/// Azúcar para la UI: `ref.perfilNegocio` y `ref.vocab` dentro de cualquier
/// `ConsumerWidget`.
///
/// Va sobre [WidgetRef] y no sobre `BuildContext` a propósito: un
/// `context.vocab` tendría que buscar el `ProviderContainer` a mano y no
/// re-construiría el widget al cambiar de perfil desde Ajustes. Con `ref` la
/// suscripción es la normal de Riverpod.
extension BusinessProfileRefX on WidgetRef {
  BusinessProfile get perfilNegocio => watch(businessProfileProvider);

  Vocabulary get vocab => watch(vocabProvider);
}
