/// Options for switching experiences with `GlamAr.setExperience`.
sealed class ExperienceOptions {
  const ExperienceOptions();
}

/// Selects a VTO experience using the first nonblank value in this order:
/// [category], [subCategory], then [skuId].
final class VtoExperienceOptions extends ExperienceOptions {
  const VtoExperienceOptions({this.category, this.subCategory, this.skuId});

  final String? category;
  final String? subCategory;
  final String? skuId;
}

/// Selects a Skin Analysis experience. [appId] must be nonblank.
final class SkinAnalysisExperienceOptions extends ExperienceOptions {
  const SkinAnalysisExperienceOptions({this.appId});

  final String? appId;
}
