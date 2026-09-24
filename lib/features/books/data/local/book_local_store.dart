import '../../../../core/offline/stores/package_store.dart';
import '../book_model.dart';

/// Feature store managing offline Book unit resolution from downloaded package records.
class BookLocalStore {
  static final BookLocalStore _instance = BookLocalStore._internal();
  factory BookLocalStore({PackageStore? packageStore}) {
    if (packageStore != null) {
      return BookLocalStore._withPackageStore(packageStore);
    }
    return _instance;
  }
  BookLocalStore._internal() : _packageStore = PackageStore();
  BookLocalStore._withPackageStore(this._packageStore);

  final PackageStore _packageStore;

  Future<List<BookUnit>> getOfflineBookUnits({
    required String grade,
    required String subject,
  }) async {
    final cleanGrade = grade.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final cleanSubject = subject.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final packageId = 'book_${cleanGrade}_$cleanSubject';
    final pkg = await _packageStore.getPackage(packageId);
    if (pkg == null || pkg.extraData['units'] is! List) return [];
    final rawList = pkg.extraData['units'] as List;
    final List<BookUnit> units = [];
    for (final item in rawList) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id'] as String? ?? '';
        units.add(BookUnit.fromMap(id, map));
      }
    }
    units.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    return units;
  }
}
