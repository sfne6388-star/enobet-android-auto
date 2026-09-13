import '../models/hizmet.dart';
import 'hizli_yerel_hizmet_servisi.dart';

/// Arama kutusu, il/ilçe sınırı olmadan uygulamadaki bütün kayıtları tarar.
class TurkiyeHizmetServisi {
  Future<List<Hizmet>> getir() => YerelHizmetServisi.ortak.tumu();
}
