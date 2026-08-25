/// Translation keys. Every user-facing string goes through here and is
/// wrapped with easy_localization's `.tr()` at the call site — screens never
/// hold literal copy.
///
/// Keys must exist in assets/translations/*.json or `.tr()` echoes the key.
class StringRes {
  // ── App ──────────────────────────────────────────────────────────────────
  static const String appName = 'appName';

  // ── Create account ───────────────────────────────────────────────────────
  static const String createAccountTitle = 'createAccountTitle';
  static const String createAccountDesc = 'createAccountDesc';
  static const String fullName = 'fullName';
  static const String enterYourFullName = 'enterYourFullName';
  static const String create = 'create';

  // ── Auth, shared ─────────────────────────────────────────────────────────
  static const String login = 'login';
  static const String logout = 'logout';
  static const String email = 'email';
  static const String enterYourEmail = 'enterYourEmail';
  static const String password = 'password';
  static const String enterYourPassword = 'enterYourPassword';
  static const String confirmPassword = 'confirmPassword';
  static const String forgotPassword = 'forgotPassword';
  static const String resetPassword = 'resetPassword';
  static const String verifyEmail = 'verifyEmail';
  static const String resendVerification = 'resendVerification';
  static const String skip = 'skip';
  static const String signIn = 'signIn';
  static const String salesmanLoginTitle = 'salesmanLoginTitle';
  static const String salesmanLoginDesc = 'salesmanLoginDesc';
  static const String invalidCredentials = 'invalidCredentials';

  // Vendor auth: login + self-registration (SPEC 1, 3.1)
  static const String vendorLoginTitle = 'vendorLoginTitle';
  static const String vendorLoginDesc = 'vendorLoginDesc';
  static const String vendorRegisterTitle = 'vendorRegisterTitle';
  static const String vendorRegisterDesc = 'vendorRegisterDesc';
  static const String registerButton = 'registerButton';
  static const String dontHaveAccount = 'dontHaveAccount';
  static const String alreadyHaveAccount = 'alreadyHaveAccount';
  static const String verificationPendingTitle = 'verificationPendingTitle';
  static const String verificationPendingDesc = 'verificationPendingDesc';
  static const String verificationLinkSent = 'verificationLinkSent';
  static const String backToLogin = 'backToLogin';
  static const String vendorHomeTitle = 'vendorHomeTitle';
  static const String vendorHomeDesc = 'vendorHomeDesc';
  static const String retry = 'retry';

  // Vendor dashboard + self-service subscribe (SPEC 3.2, 3.9, task 4.2)
  static const String quotaSectionTitle = 'quotaSectionTitle';
  static const String noActiveSubscription = 'noActiveSubscription';
  static const String subscribeNow = 'subscribeNow';

  // Ongoing services management (SPEC 3.3, task 4.4)
  static const String servicesTab = 'servicesTab';
  static const String overviewTab = 'overviewTab';
  static const String addMoreServices = 'addMoreServices';
  static const String selectAtLeastOneNewService = 'selectAtLeastOneNewService';
  static const String servicesAdded = 'servicesAdded';
  static const String remainingLabel = 'remainingLabel';
  static const String noServicesSelected = 'noServicesSelected';

  // Vendor portfolio (SPEC 3 item 5, task 4.5)
  static const String portfolioTab = 'portfolioTab';
  static const String addPhoto = 'addPhoto';
  static const String addVideo = 'addVideo';
  static const String videoTooLarge = 'videoTooLarge';
  static const String uploadFailed = 'uploadFailed';
  static const String mediaUploaded = 'mediaUploaded';
  static const String noPortfolioYet = 'noPortfolioYet';
  static const String selectSubcategoryFirst = 'selectSubcategoryFirst';
  static const String moderationPending = 'moderationPending';
  static const String moderationApproved = 'moderationApproved';
  static const String moderationRejected = 'moderationRejected';

  // Customer flavor (SPEC 4.1, 4.2, task 4.6)
  static const String customerLoginTitle = 'customerLoginTitle';
  static const String customerLoginDesc = 'customerLoginDesc';
  static const String customerRegisterTitle = 'customerRegisterTitle';
  static const String customerRegisterDesc = 'customerRegisterDesc';
  static const String customerHomeTitle = 'customerHomeTitle';
  static const String detectingLocation = 'detectingLocation';
  static const String changeLocation = 'changeLocation';
  static const String notInYourAreaYet = 'notInYourAreaYet';
  static const String enterPincode = 'enterPincode';
  static const String submitPincode = 'submitPincode';
  static const String invalidPincode = 'invalidPincode';

  // Category browse grid (SPEC 4 items 3-4, task 5.1)
  static const String browseCategoriesTitle = 'browseCategoriesTitle';
  static const String noCategoriesYet = 'noCategoriesYet';
  static const String noSubcategoriesYet = 'noSubcategoriesYet';
  static const String vendorSearchComingSoon = 'vendorSearchComingSoon';

  // Vendor search results + detail + leads (SPEC 4 items 4/6/7, task 5.4)
  static const String noVendorsFoundYet = 'noVendorsFoundYet';
  static const String loadMore = 'loadMore';
  static const String distanceAwayLabel = 'distanceAwayLabel';
  static const String callButton = 'callButton';
  static const String whatsappButton = 'whatsappButton';
  static const String servicesOfferedSection = 'servicesOfferedSection';
  static const String photosVideosSection = 'photosVideosSection';
  static const String leadFailedTryAgain = 'leadFailedTryAgain';
  static const String newVendorLabel = 'newVendorLabel';
  static const String vendorNotFound = 'vendorNotFound';

  // Reviews (SPEC section 9, task 5.5)
  static const String reviewsSectionTitle = 'reviewsSectionTitle';
  static const String noReviewsYet = 'noReviewsYet';
  static const String writeReviewButton = 'writeReviewButton';
  static const String ratingLabel = 'ratingLabel';
  static const String reviewCommentHint = 'reviewCommentHint';
  static const String submitReview = 'submitReview';
  static const String reviewSubmitted = 'reviewSubmitted';
  static const String reviewSubmitFailed = 'reviewSubmitFailed';
  static const String vendorReplyLabel = 'vendorReplyLabel';
  static const String selectARatingFirst = 'selectARatingFirst';

  // Vendor Leads + Reviews tabs (SPEC section 3 items 7-8, task 4.8)
  static const String leadsTab = 'leadsTab';
  static const String reviewsTab = 'reviewsTab';
  static const String noLeadsYet = 'noLeadsYet';
  static const String requestReviewButton = 'requestReviewButton';
  static const String reviewAlreadyRequested = 'reviewAlreadyRequested';
  static const String reviewAlreadyLeft = 'reviewAlreadyLeft';
  static const String reviewRequestSent = 'reviewRequestSent';
  static const String reviewRequestFailed = 'reviewRequestFailed';
  static const String noReviewsYetVendor = 'noReviewsYetVendor';
  static const String hiddenByAdminLabel = 'hiddenByAdminLabel';
  static const String replyButton = 'replyButton';
  static const String yourReplyLabel = 'yourReplyLabel';
  static const String submitReply = 'submitReply';

  // Forced first-login password change (SPEC 2.1)
  static const String changePasswordTitle = 'changePasswordTitle';
  static const String changePasswordDesc = 'changePasswordDesc';
  static const String currentPassword = 'currentPassword';
  static const String enterCurrentPassword = 'enterCurrentPassword';
  static const String newPassword = 'newPassword';
  static const String enterNewPassword = 'enterNewPassword';
  static const String confirmNewPassword = 'confirmNewPassword';
  static const String passwordChanged = 'passwordChanged';
  static const String salesmanHomeTitle = 'salesmanHomeTitle';
  static const String salesmanHomeDesc = 'salesmanHomeDesc';
  static const String signOut = 'signOut';

  // Salesman home tabs: My Vendors, Earnings (SPEC 2.3, 2.4)
  static const String myVendorsTab = 'myVendorsTab';
  static const String earningsTab = 'earningsTab';
  static const String noVendorsYet = 'noVendorsYet';
  static const String notSubscribed = 'notSubscribed';
  static const String daysLeft = 'daysLeft';
  static const String expiredDaysAgo = 'expiredDaysAgo';
  static const String daysAgoSuffix = 'daysAgoSuffix';
  static const String pendingCommission = 'pendingCommission';
  static const String paidCommission = 'paidCommission';
  static const String commissionCount = 'commissionCount';

  // Add Vendor, step 1 (SPEC 2.2)
  static const String addVendorTitle = 'addVendorTitle';
  static const String addVendorDesc = 'addVendorDesc';
  static const String businessName = 'businessName';
  static const String enterBusinessName = 'enterBusinessName';
  static const String ownerName = 'ownerName';
  static const String enterOwnerName = 'enterOwnerName';
  static const String phone = 'phone';
  static const String enterPhone = 'enterPhone';
  static const String invalidPhone = 'invalidPhone';
  static const String address = 'address';
  static const String enterAddress = 'enterAddress';
  static const String kycSection = 'kycSection';
  static const String shopPhoto = 'shopPhoto';
  static const String idProof = 'idProof';
  static const String idProofTypeLabel = 'idProofTypeLabel';
  static const String aadhaar = 'aadhaar';
  static const String pan = 'pan';
  static const String tapToUpload = 'tapToUpload';
  static const String replaceImage = 'replaceImage';
  static const String saveDraft = 'saveDraft';
  static const String draftSaved = 'draftSaved';
  static const String draftResumed = 'draftResumed';
  static const String kycUploadFailed = 'kycUploadFailed';
  static const String draftBanner = 'draftBanner';
  static const String shopLocation = 'shopLocation';
  static const String captureLocation = 'captureLocation';
  static const String locationCaptured = 'locationCaptured';
  static const String locationServiceDisabled = 'locationServiceDisabled';
  static const String locationPermissionDenied = 'locationPermissionDenied';
  static const String locationCaptureFailed = 'locationCaptureFailed';

  // Add Vendor, step 2 (SPEC 2.2): plan -> categories/subcategories -> zones
  static const String selectPlanTitle = 'selectPlanTitle';
  static const String selectPlanDesc = 'selectPlanDesc';
  static const String continueLabel = 'continueLabel';
  static const String selectAPlanFirst = 'selectAPlanFirst';
  static const String perDay = 'perDay';
  static const String selectServicesTitle = 'selectServicesTitle';
  static const String selectServicesDesc = 'selectServicesDesc';
  static const String categoriesSection = 'categoriesSection';
  static const String subcategoriesCounted = 'subcategoriesCounted';
  static const String zonesSection = 'zonesSection';
  static const String categoryQuotaReached = 'categoryQuotaReached';
  static const String subcategoryQuotaReached = 'subcategoryQuotaReached';
  static const String zoneQuotaReached = 'zoneQuotaReached';
  static const String selectACategory = 'selectACategory';
  static const String selectASubcategory = 'selectASubcategory';
  static const String selectAZone = 'selectAZone';
  static const String selectionsCaptured = 'selectionsCaptured';
  static const String of = 'of';

  // Subscribe: payment mode + confirmation (SPEC 2.2, 6)
  static const String choosePaymentMode = 'choosePaymentMode';
  static const String paymentModeCash = 'paymentModeCash';
  static const String paymentModeOnline = 'paymentModeOnline';
  static const String paymentModeFree = 'paymentModeFree';
  static const String freeTrialDurationLabel = 'freeTrialDurationLabel';
  static const String freeTrialCappedAt = 'freeTrialCappedAt';
  static const String daysUnit = 'daysUnit';
  static const String confirmSubscribe = 'confirmSubscribe';
  static const String cancel = 'cancel';
  static const String subscribeFailed = 'subscribeFailed';
  static const String subscriptionConfirmedTitle = 'subscriptionConfirmedTitle';
  static const String subscriptionConfirmedDesc = 'subscriptionConfirmedDesc';
  static const String loginEmailLabel = 'loginEmailLabel';
  static const String temporaryPasswordLabel = 'temporaryPasswordLabel';
  static const String shareViaWhatsapp = 'shareViaWhatsapp';
  static const String done = 'done';
  static const String planLabel = 'planLabel';
  static const String priceLabel = 'priceLabel';

  // ── Validation ───────────────────────────────────────────────────────────
  static const String fieldRequired = 'fieldRequired';
  static const String invalidEmail = 'invalidEmail';
  static const String passwordTooShort = 'passwordTooShort';
  static const String passwordsDoNotMatch = 'passwordsDoNotMatch';

  // ── Errors ───────────────────────────────────────────────────────────────
  static const String somethingWentWrong = 'somethingWentWrong';
  static const String noInternet = 'noInternet';

  // ── Favorites / share / report vendor / account deletion (SPEC 4 item 10)
  static const String favoritesTab = 'favoritesTab';
  static const String noFavoritesYet = 'noFavoritesYet';
  static const String shareProfileButton = 'shareProfileButton';
  static const String reportVendorMenuItem = 'reportVendorMenuItem';
  static const String reportVendorTitle = 'reportVendorTitle';
  static const String reportVendorReasonHint = 'reportVendorReasonHint';
  static const String reportVendorSubmitButton = 'reportVendorSubmitButton';
  static const String reportVendorSubmitted = 'reportVendorSubmitted';
  static const String reportVendorFailed = 'reportVendorFailed';
  static const String selectAReasonFirst = 'selectAReasonFirst';
  static const String deleteAccountMenuItem = 'deleteAccountMenuItem';
  static const String deleteAccountTitle = 'deleteAccountTitle';
  static const String deleteAccountWarning = 'deleteAccountWarning';
  static const String deleteAccountPasswordHint = 'deleteAccountPasswordHint';
  static const String deleteAccountConfirmButton = 'deleteAccountConfirmButton';
  static const String deleteAccountSucceeded = 'deleteAccountSucceeded';
}
