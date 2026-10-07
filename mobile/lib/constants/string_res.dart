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
  static const String forgotPasswordHelp = 'forgotPasswordHelp';

  // Vendor app redesign — plan selection (SPEC 3.2).
  static const String vendorSelectPlanStep = 'vendorSelectPlanStep';
  static const String vendorDashboardEyebrow = 'vendorDashboardEyebrow';
  static const String vendorOverviewTitle = 'vendorOverviewTitle';
  static const String vendorCurrentPlan = 'vendorCurrentPlan';
  static const String vendorDaysLeft = 'vendorDaysLeft';
  static const String vendorPlanUsage = 'vendorPlanUsage';
  static const String vendorLimitsCount = 'vendorLimitsCount';
  static const String vendorNeedMoreRoom = 'vendorNeedMoreRoom';
  static const String vendorUpgradePitch = 'vendorUpgradePitch';
  static const String vendorUpgrade = 'vendorUpgrade';
  static const String vendorServicesTitle = 'vendorServicesTitle';
  static const String vendorServicesDesc = 'vendorServicesDesc';
  static const String vendorUsedOf = 'vendorUsedOf';
  static const String vendorLeftCount = 'vendorLeftCount';
  static const String vendorPortfolioTitle = 'vendorPortfolioTitle';
  static const String vendorPortfolioDesc = 'vendorPortfolioDesc';
  static const String vendorTagUploads = 'vendorTagUploads';
  static const String vendorNoPortfolio = 'vendorNoPortfolio';
  static const String vendorNoPortfolioDesc = 'vendorNoPortfolioDesc';
  static const String vendorAddPhoto = 'vendorAddPhoto';
  static const String vendorAddVideo = 'vendorAddVideo';
  static const String vendorProfileTitle = 'vendorProfileTitle';
  static const String vendorPlanPill = 'vendorPlanPill';
  static const String vendorZoneSingular = 'vendorZoneSingular';
  static const String vendorAccountGroup = 'vendorAccountGroup';
  static const String vendorBusinessDetails = 'vendorBusinessDetails';
  static const String vendorBusinessDetailsSub = 'vendorBusinessDetailsSub';
  static const String vendorContactDetails = 'vendorContactDetails';
  static const String vendorContactDetailsSub = 'vendorContactDetailsSub';
  static const String vendorSubscriptionGroup = 'vendorSubscriptionGroup';
  static const String vendorCurrentPlanSub = 'vendorCurrentPlanSub';
  static const String vendorUpgradeTo = 'vendorUpgradeTo';
  static const String vendorUpgradeToSub = 'vendorUpgradeToSub';
  static const String vendorAppFooter = 'vendorAppFooter';
  static const String vendorConfirmPaymentTitle = 'vendorConfirmPaymentTitle';
  static const String vendorConfirmPaymentBody = 'vendorConfirmPaymentBody';
  static const String vendorConfirmPaymentOnlineNote = 'vendorConfirmPaymentOnlineNote';
  static const String vendorPayNow = 'vendorPayNow';
  static const String vendorAmountDue = 'vendorAmountDue';

  // Vendor business details + current plan screens (SPEC 3.2).
  static const String vendorBusinessDetailsTitle = 'vendorBusinessDetailsTitle';
  static const String vendorChangeLogo = 'vendorChangeLogo';
  static const String vendorCityLabel = 'vendorCityLabel';
  static const String vendorCityHint = 'vendorCityHint';
  static const String vendorAboutLabel = 'vendorAboutLabel';
  static const String vendorAboutHint = 'vendorAboutHint';
  static const String vendorAddressHint = 'vendorAddressHint';
  static const String vendorContactSection = 'vendorContactSection';
  static const String vendorSaveChanges = 'vendorSaveChanges';
  static const String vendorProfileSaved = 'vendorProfileSaved';
  static const String vendorEmailReadOnly = 'vendorEmailReadOnly';
  static const String vendorEmailReadOnlyNote = 'vendorEmailReadOnlyNote';
  static const String vendorCurrentPlanTitle = 'vendorCurrentPlanTitle';
  static const String vendorPlanActive = 'vendorPlanActive';
  static const String vendorTimeRemaining = 'vendorTimeRemaining';
  static const String vendorWhatsIncluded = 'vendorWhatsIncluded';
  static const String vendorTapRowForDetails = 'vendorTapRowForDetails';
  static const String vendorSlotsAvailable = 'vendorSlotsAvailable';
  static const String vendorManage = 'vendorManage';
  static const String vendorEmptySlot = 'vendorEmptySlot';
  static const String vendorNoneSelectedYet = 'vendorNoneSelectedYet';
  static const String comingSoon = 'comingSoon';
  static const String passwordShouldHave = 'passwordShouldHave';
  static const String passwordRuleLength = 'passwordRuleLength';
  static const String passwordRuleMatch = 'passwordRuleMatch';
  static const String vendorSelectPlanDesc = 'vendorSelectPlanDesc';
  static const String planForDays = 'planForDays';
  static const String continueWithPlan = 'continueWithPlan';
  static const String planCategories = 'planCategories';
  static const String planSubcategories = 'planSubcategories';
  static const String planZones = 'planZones';
  static const String planPhotos = 'planPhotos';
  static const String planVideos = 'planVideos';
  static const String skip = 'skip';
  static const String signIn = 'signIn';
  static const String salesmanLoginTitle = 'salesmanLoginTitle';
  static const String salesmanLoginDesc = 'salesmanLoginDesc';
  static const String invalidCredentials = 'invalidCredentials';
  static const String wrongAppForAccount = 'wrongAppForAccount';

  // Vendor auth: login + self-registration (SPEC 1, 3.1)
  static const String vendorLoginTitle = 'vendorLoginTitle';
  static const String vendorLoginDesc = 'vendorLoginDesc';
  static const String vendorRegisterTitle = 'vendorRegisterTitle';
  static const String vendorRegisterDesc = 'vendorRegisterDesc';
  static const String registerButton = 'registerButton';
  static const String dontHaveAccount = 'dontHaveAccount';
  static const String alreadyHaveAccount = 'alreadyHaveAccount';
  static const String backToLogin = 'backToLogin';

  // Account verification by an admin (SPEC 3.1) — the single gate on an
  // account, in place of the email verification this replaced.
  static const String accountVerificationTitle = 'accountVerificationTitle';
  static const String accountVerificationDesc = 'accountVerificationDesc';
  static const String accountRejectedTitle = 'accountRejectedTitle';
  static const String accountRejectedDesc = 'accountRejectedDesc';
  static const String checkVerificationStatus = 'checkVerificationStatus';
  static const String accountStillPending = 'accountStillPending';
  static const String verifyStepCreated = 'verifyStepCreated';
  static const String verifyStepCreatedSub = 'verifyStepCreatedSub';
  static const String verifyStepReview = 'verifyStepReview';
  static const String verifyStepReviewSub = 'verifyStepReviewSub';
  static const String verifyStepReviewDoneSub = 'verifyStepReviewDoneSub';
  static const String verifyStepApproved = 'verifyStepApproved';
  static const String verifyStepApprovedSub = 'verifyStepApprovedSub';
  static const String verifyStepRejected = 'verifyStepRejected';
  static const String verifyStepRejectedSub = 'verifyStepRejectedSub';
  static const String accountApproved = 'accountApproved';
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
  static const String imageLoadFailed = 'imageLoadFailed';
  static const String vendorUploadingPhoto = 'vendorUploadingPhoto';
  static const String vendorUploadingVideo = 'vendorUploadingVideo';
  static const String vendorUploadFinishing = 'vendorUploadFinishing';
  static const String videoLoadFailed = 'videoLoadFailed';
  static const String vendorNoPortfolioForService = 'vendorNoPortfolioForService';
  static const String vendorNoPortfolioForServiceDesc = 'vendorNoPortfolioForServiceDesc';
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
  static const String searchSubcategoriesHint = 'searchSubcategoriesHint';
  static const String noMatchingServices = 'noMatchingServices';
  static const String allCategoriesFilter = 'allCategoriesFilter';
  static const String selectedSuffix = 'selectedSuffix';
  static const String pickedSuffix = 'pickedSuffix';
  static const String subcategoriesLeftInPlan = 'subcategoriesLeftInPlan';
  static const String planSuffix = 'planSuffix';
  static const String areasAvailable = 'areasAvailable';
  static const String zonesLeftLabel = 'zonesLeftLabel';
  static const String zonesCountTowardLimit = 'zonesCountTowardLimit';
  static const String stepLabel = 'stepLabel';
  static const String coverageZonesTitle = 'coverageZonesTitle';
  static const String coverageZonesDesc = 'coverageZonesDesc';
  static const String selectAllLabel = 'selectAllLabel';
  static const String tapToChoose = 'tapToChoose';
  static const String allLabel = 'allLabel';
  static const String zonesInThisPlan = 'zonesInThisPlan';
  static const String leftLabel = 'leftLabel';
  static const String zonesUnit = 'zonesUnit';
  static const String noMatchingZones = 'noMatchingZones';
  static const String salesmanPortal = 'salesmanPortal';
  static const String salesmanPortalDesc = 'salesmanPortalDesc';
  static const String vendorPortal = 'vendorPortal';
  static const String vendorPortalDesc = 'vendorPortalDesc';
  static const String customerPortal = 'customerPortal';
  static const String customerPortalDesc = 'customerPortalDesc';
  static const String rememberMe = 'rememberMe';
  static const String firstLoginTip = 'firstLoginTip';
  static const String enterEmailFirst = 'enterEmailFirst';
  static const String welcomeBack = 'welcomeBack';
  static const String yourVendors = 'yourVendors';
  static const String totalVendors = 'totalVendors';
  static const String subscribedLabel = 'subscribedLabel';
  static const String earningsLabel = 'earningsLabel';
  static const String searchVendorsHint = 'searchVendorsHint';
  static const String vendorsCountLabel = 'vendorsCountLabel';
  static const String sortRecent = 'sortRecent';
  static const String addVendorFab = 'addVendorFab';
  static const String noActivePlan = 'noActivePlan';
  static const String subscribeAction = 'subscribeAction';
  static const String expiresLabel = 'expiresLabel';
  static const String activeLabel = 'activeLabel';
  static const String profileTitle = 'profileTitle';
  static const String personalDetails = 'personalDetails';
  static const String personalDetailsSub = 'personalDetailsSub';
  static const String assignedRegion = 'assignedRegion';
  static const String notSetLabel = 'notSetLabel';
  static const String changePasswordRow = 'changePasswordRow';
  static const String performanceGroup = 'performanceGroup';
  static const String accountGroup = 'accountGroup';
  static const String preferencesGroup = 'preferencesGroup';
  static const String earningsPayouts = 'earningsPayouts';
  static const String thisMonthLabel = 'thisMonthLabel';
  static const String targetsRow = 'targetsRow';
  static const String notificationsRow = 'notificationsRow';
  static const String languageRow = 'languageRow';
  static const String helpSupport = 'helpSupport';
  static const String logOutAction = 'logOutAction';
  static const String deleteAccountAction = 'deleteAccountAction';
  static const String appVersionLabel = 'appVersionLabel';
  static const String fieldSalesman = 'fieldSalesman';
  static const String callAction = 'callAction';
  static const String emailAction = 'emailAction';
  static const String messageAction = 'messageAction';
  static const String planUsage = 'planUsage';
  static const String manageAction = 'manageAction';
  static const String editAction = 'editAction';
  static const String deleteVendorAction = 'deleteVendorAction';
  static const String ownerLabel = 'ownerLabel';
  static const String photosLabel = 'photosLabel';
  static const String videosLabel = 'videosLabel';
  static const String saveAction = 'saveAction';
  static const String profileUpdated = 'profileUpdated';
  static const String nameLabel = 'nameLabel';
  static const String enterYourName = 'enterYourName';
  static const String employeeCodeLabel = 'employeeCodeLabel';
  static const String commissionRateLabel = 'commissionRateLabel';
  static const String noVendorsMatch = 'noVendorsMatch';
  static const String deleteVendorUnavailable = 'deleteVendorUnavailable';
  static const String helpSupportBody = 'helpSupportBody';
  static const String vendorDetailTitle = 'vendorDetailTitle';
  static const String contactSection = 'contactSection';
  static const String planSection = 'planSection';
  static const String expiresOn = 'expiresOn';
  static const String vendorStatusLabel = 'vendorStatusLabel';
  static const String coverageZonesSection = 'coverageZonesSection';
  static const String searchAnAreaHint = 'searchAnAreaHint';
  static const String zonesSelectedLabel = 'zonesSelectedLabel';
  static const String stillAvailableLabel = 'stillAvailableLabel';

  // Subscribe: payment mode + confirmation (SPEC 2.2, 6)
  static const String choosePaymentMode = 'choosePaymentMode';
  static const String choosePaymentModeDesc = 'choosePaymentModeDesc';
  static const String paymentModeCashDesc = 'paymentModeCashDesc';
  static const String paymentModeOnlineDesc = 'paymentModeOnlineDesc';
  static const String paymentModeFreeDesc = 'paymentModeFreeDesc';
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

  static const String seeAll = 'seeAll';
  static const String homeTab = 'homeTab';
  static const String profileTab = 'profileTab';
  static const String customerGreeting = 'customerGreeting';
  static const String customerSearchHint = 'customerSearchHint';
  static const String yourLocationLabel = 'yourLocationLabel';
  static const String setYourLocation = 'setYourLocation';
  static const String popularServices = 'popularServices';
  static const String vendorsNearYou = 'vendorsNearYou';
  static const String newVendorBadge = 'newVendorBadge';
  static const String noVendorsNearby = 'noVendorsNearby';
  static const String noVendorsNearbyDesc = 'noVendorsNearbyDesc';
  static const String selectLocationTitle = 'selectLocationTitle';
  static const String searchLocationHint = 'searchLocationHint';
  static const String useCurrentLocation = 'useCurrentLocation';
  static const String useCurrentLocationDesc = 'useCurrentLocationDesc';
  static const String chooseOnMap = 'chooseOnMap';
  static const String chooseOnMapDesc = 'chooseOnMapDesc';
  static const String searchResultsLabel = 'searchResultsLabel';
  static const String poweredByGoogle = 'poweredByGoogle';
  static const String noPlacesFound = 'noPlacesFound';
  static const String noPlacesFoundDesc = 'noPlacesFoundDesc';
  static const String locationNotResolved = 'locationNotResolved';
  static const String currentLocationTitle = 'currentLocationTitle';
  static const String detectedViaGps = 'detectedViaGps';
  static const String latitudeLabel = 'latitudeLabel';
  static const String longitudeLabel = 'longitudeLabel';
  static const String confirmLocation = 'confirmLocation';
  static const String chooseDifferentLocation = 'chooseDifferentLocation';
  static const String locationUnavailable = 'locationUnavailable';
  static const String locationUnavailableDesc = 'locationUnavailableDesc';
  static const String retryDetect = 'retryDetect';
  static const String mapLocationTitle = 'mapLocationTitle';
  static const String moveMapToAdjustPin = 'moveMapToAdjustPin';
  static const String selectedLocationLabel = 'selectedLocationLabel';
  static const String locateMe = 'locateMe';
  static const String profileScreenTitle = 'profileScreenTitle';
  static const String yourNameFallback = 'yourNameFallback';
  static const String myReviewsTitle = 'myReviewsTitle';
  static const String favouritesCardDesc = 'favouritesCardDesc';
  static const String myReviewsCardDesc = 'myReviewsCardDesc';
  static const String accountSection = 'accountSection';
  static const String personalDetailsDesc = 'personalDetailsDesc';
  static const String savedLocationRow = 'savedLocationRow';
  static const String noLocationSet = 'noLocationSet';
  static const String preferencesSection = 'preferencesSection';
  static const String helpSupportRow = 'helpSupportRow';
  static const String logOutRow = 'logOutRow';
  static const String deleteAccountRow = 'deleteAccountRow';
  static const String serviceSearchTitle = 'serviceSearchTitle';
  static const String allServicesLabel = 'allServicesLabel';
  static const String noServicesFound = 'noServicesFound';
  static const String noServicesFoundDesc = 'noServicesFoundDesc';
  static const String searchInCategoryHint = 'searchInCategoryHint';
  static const String filterAll = 'filterAll';
  static const String filterInstallation = 'filterInstallation';
  static const String filterRepair = 'filterRepair';
  static const String filterMaintenance = 'filterMaintenance';
  static const String allServicesHeading = 'allServicesHeading';
  static const String serviceCountLabel = 'serviceCountLabel';
  static const String popularBadge = 'popularBadge';
  static const String vendorsCountSuffix = 'vendorsCountSuffix';
  static const String vendorCountSuffix = 'vendorCountSuffix';
  static const String noServicesMatchFilter = 'noServicesMatchFilter';
  static const String noServicesMatchFilterDesc = 'noServicesMatchFilterDesc';
  static const String chooseAServiceDesc = 'chooseAServiceDesc';
}
