import 'package:flutter/material.dart';

/// Transaction type enum
enum TransactionType { expense, income }

/// Category model for transaction categorization with hierarchy support
class Category {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final bool isDefault;
  final String? parentId; // null이면 대분류, 값이 있으면 소분류
  final TransactionType type;

  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isDefault = false,
    this.parentId,
    this.type = TransactionType.expense,
  });

  /// Check if this is a parent category (대분류)
  bool get isParent => parentId == null;

  /// Check if this is a subcategory (소분류)
  bool get isSubcategory => parentId != null;

  // ============================================================
  // 지출 대분류 카테고리 (Expense Parent Categories)
  // ============================================================
  static List<Category> get expenseParentCategories => [
    const Category(
      id: 'food',
      name: '식비',
      emoji: '🍽️',
      color: Color(0xFFFF6B6B),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'transport',
      name: '교통비',
      emoji: '🚗',
      color: Color(0xFF4ECDC4),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'housing',
      name: '주거비',
      emoji: '🏠',
      color: Color(0xFF9B59B6),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'communication',
      name: '통신비',
      emoji: '📱',
      color: Color(0xFF3498DB),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'fashion',
      name: '의류/미용',
      emoji: '👔',
      color: Color(0xFFE91E63),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'living',
      name: '생활용품',
      emoji: '🛒',
      color: Color(0xFFFFE66D),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'health',
      name: '건강/의료',
      emoji: '🏥',
      color: Color(0xFF95E1D3),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'leisure',
      name: '여가/문화',
      emoji: '🎮',
      color: Color(0xFFA8E6CF),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'subscription',
      name: '구독서비스',
      emoji: '📺',
      color: Color(0xFF00BCD4),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'education',
      name: '교육',
      emoji: '📖',
      color: Color(0xFF8BC34A),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'events',
      name: '경조사/선물',
      emoji: '💝',
      color: Color(0xFFFF9800),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'finance',
      name: '금융',
      emoji: '💰',
      color: Color(0xFF607D8B),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'childcare',
      name: '육아/자녀',
      emoji: '👶',
      color: Color(0xFFFFAB91),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'pet',
      name: '반려동물',
      emoji: '🐾',
      color: Color(0xFFBCAAA4),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'car',
      name: '자동차',
      emoji: '🚙',
      color: Color(0xFF78909C),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'insurance',
      name: '보험',
      emoji: '🛡️',
      color: Color(0xFF5C6BC0),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'tax',
      name: '세금/공과금',
      emoji: '🏛️',
      color: Color(0xFF8D6E63),
      isDefault: true,
      type: TransactionType.expense,
    ),
    const Category(
      id: 'other_expense',
      name: '기타',
      emoji: '📦',
      color: Color(0xFFBDC3C7),
      isDefault: true,
      type: TransactionType.expense,
    ),
  ];

  // ============================================================
  // 지출 소분류 카테고리 (Expense Subcategories)
  // ============================================================
  static List<Category> get expenseSubcategories => [
    // 🍽️ 식비 하위
    const Category(id: 'food_restaurant', name: '외식', emoji: '🍴', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_delivery', name: '배달/포장', emoji: '🛵', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_grocery', name: '식료품', emoji: '🥬', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_cafe', name: '카페/음료', emoji: '☕', color: Color(0xFFD4A574), parentId: 'food', isDefault: true),
    const Category(id: 'food_snack', name: '간식', emoji: '🍫', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_alcohol', name: '술/회식', emoji: '🍺', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_convenience', name: '편의점', emoji: '🏪', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_school', name: '학교급식', emoji: '🍱', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),
    const Category(id: 'food_bakery', name: '베이커리', emoji: '🥐', color: Color(0xFFFF6B6B), parentId: 'food', isDefault: true),

    // 🚗 교통비 하위
    const Category(id: 'transport_public', name: '대중교통', emoji: '🚇', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_taxi', name: '택시', emoji: '🚕', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_fuel', name: '주유비', emoji: '⛽', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_parking', name: '주차비', emoji: '🅿️', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_toll', name: '통행료', emoji: '🛣️', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_train', name: '기차/KTX', emoji: '🚄', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_bus', name: '고속버스', emoji: '🚌', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_flight', name: '항공', emoji: '✈️', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_rental', name: '렌터카/킥보드', emoji: '🛴', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),
    const Category(id: 'transport_ship', name: '배/페리', emoji: '🚢', color: Color(0xFF4ECDC4), parentId: 'transport', isDefault: true),

    // 🏠 주거비 하위
    const Category(id: 'housing_rent', name: '월세', emoji: '🏠', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_loan', name: '주택대출', emoji: '🏦', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_maintenance', name: '관리비', emoji: '🏢', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_electricity', name: '전기세', emoji: '⚡', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_gas', name: '가스비', emoji: '🔥', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_water', name: '수도세', emoji: '💧', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_internet', name: '인터넷/TV', emoji: '📡', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_repair', name: '수리/인테리어', emoji: '🔨', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),
    const Category(id: 'housing_cleaning', name: '청소용역', emoji: '🧹', color: Color(0xFF9B59B6), parentId: 'housing', isDefault: true),

    // 📱 통신비 하위
    const Category(id: 'comm_phone', name: '휴대폰요금', emoji: '📱', color: Color(0xFF3498DB), parentId: 'communication', isDefault: true),
    const Category(id: 'comm_data', name: '데이터요금', emoji: '📶', color: Color(0xFF3498DB), parentId: 'communication', isDefault: true),
    const Category(id: 'comm_device', name: '기기할부금', emoji: '💻', color: Color(0xFF3498DB), parentId: 'communication', isDefault: true),

    // 👔 의류/미용 하위
    const Category(id: 'fashion_clothes', name: '의류', emoji: '👕', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_shoes', name: '신발', emoji: '👟', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_accessory', name: '잡화/액세서리', emoji: '👜', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_beauty', name: '화장품', emoji: '💄', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_hair', name: '헤어', emoji: '💇', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_nail', name: '네일', emoji: '💅', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_skincare', name: '피부관리', emoji: '✨', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),
    const Category(id: 'fashion_laundry', name: '세탁/수선', emoji: '👗', color: Color(0xFFE91E63), parentId: 'fashion', isDefault: true),

    // 🛒 생활용품 하위
    const Category(id: 'living_household', name: '생필품', emoji: '🧴', color: Color(0xFFFFE66D), parentId: 'living', isDefault: true),
    const Category(id: 'living_furniture', name: '가구', emoji: '🛋️', color: Color(0xFFFFE66D), parentId: 'living', isDefault: true),
    const Category(id: 'living_appliance', name: '가전제품', emoji: '🔌', color: Color(0xFFFFE66D), parentId: 'living', isDefault: true),
    const Category(id: 'living_kitchenware', name: '주방용품', emoji: '🍳', color: Color(0xFFFFE66D), parentId: 'living', isDefault: true),
    const Category(id: 'living_interior', name: '인테리어소품', emoji: '🖼️', color: Color(0xFFFFE66D), parentId: 'living', isDefault: true),
    const Category(id: 'living_stationery', name: '문구/사무용품', emoji: '📎', color: Color(0xFFFFE66D), parentId: 'living', isDefault: true),

    // 🏥 건강/의료 하위
    const Category(id: 'health_hospital', name: '병원비', emoji: '🏥', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_pharmacy', name: '약국', emoji: '💊', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_supplement', name: '건강보조제', emoji: '💪', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_exercise', name: '운동/헬스', emoji: '🏋️', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_checkup', name: '건강검진', emoji: '🔬', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_dental', name: '치과', emoji: '🦷', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_dermatology', name: '피부과', emoji: '🧴', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_oriental', name: '한의원', emoji: '🌿', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_eye', name: '안과/안경', emoji: '👓', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),
    const Category(id: 'health_mental', name: '심리상담', emoji: '🧠', color: Color(0xFF95E1D3), parentId: 'health', isDefault: true),

    // 🎮 여가/문화 하위
    const Category(id: 'leisure_movie', name: '영화', emoji: '🎬', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_performance', name: '공연/전시', emoji: '🎭', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_book', name: '도서', emoji: '📚', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_game', name: '게임', emoji: '🎮', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_hobby', name: '취미', emoji: '🎨', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_travel', name: '여행', emoji: '✈️', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_accommodation', name: '숙박', emoji: '🏨', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_sports', name: '스포츠관람', emoji: '⚽', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_theme', name: '놀이공원', emoji: '🎡', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_music', name: '음악/콘서트', emoji: '🎵', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_camping', name: '캠핑', emoji: '⛺', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_fishing', name: '낚시', emoji: '🎣', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),
    const Category(id: 'leisure_golf', name: '골프', emoji: '⛳', color: Color(0xFFA8E6CF), parentId: 'leisure', isDefault: true),

    // 📺 구독서비스 하위
    const Category(id: 'subs_streaming', name: 'OTT스트리밍', emoji: '📺', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),
    const Category(id: 'subs_music', name: '음악스트리밍', emoji: '🎵', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),
    const Category(id: 'subs_cloud', name: '클라우드', emoji: '☁️', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),
    const Category(id: 'subs_app', name: '앱/소프트웨어', emoji: '📲', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),
    const Category(id: 'subs_membership', name: '멤버십', emoji: '🎫', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),
    const Category(id: 'subs_news', name: '신문/잡지', emoji: '📰', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),
    const Category(id: 'subs_gym', name: '헬스장이용권', emoji: '🏋️', color: Color(0xFF00BCD4), parentId: 'subscription', isDefault: true),

    // 📖 교육 하위
    const Category(id: 'edu_tuition', name: '등록금', emoji: '🎓', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),
    const Category(id: 'edu_academy', name: '학원비', emoji: '✏️', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),
    const Category(id: 'edu_lecture', name: '강의/교재', emoji: '📖', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),
    const Category(id: 'edu_certificate', name: '자격증', emoji: '📜', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),
    const Category(id: 'edu_online', name: '온라인강의', emoji: '💻', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),
    const Category(id: 'edu_language', name: '어학/유학', emoji: '🌍', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),
    const Category(id: 'edu_supplies', name: '학용품', emoji: '🎒', color: Color(0xFF8BC34A), parentId: 'education', isDefault: true),

    // 💝 경조사/선물 하위
    const Category(id: 'events_wedding', name: '축의금', emoji: '💒', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),
    const Category(id: 'events_funeral', name: '조의금', emoji: '🖤', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),
    const Category(id: 'events_gift', name: '선물', emoji: '🎁', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),
    const Category(id: 'events_donation', name: '기부', emoji: '❤️', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),
    const Category(id: 'events_birthday', name: '생일', emoji: '🎂', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),
    const Category(id: 'events_anniversary', name: '기념일', emoji: '💐', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),
    const Category(id: 'events_housewarming', name: '집들이', emoji: '🏡', color: Color(0xFFFF9800), parentId: 'events', isDefault: true),

    // 💰 금융 하위
    const Category(id: 'finance_loan', name: '대출상환', emoji: '💳', color: Color(0xFF607D8B), parentId: 'finance', isDefault: true),
    const Category(id: 'finance_fee', name: '수수료', emoji: '🏧', color: Color(0xFF607D8B), parentId: 'finance', isDefault: true),
    const Category(id: 'finance_invest', name: '투자금', emoji: '📊', color: Color(0xFF607D8B), parentId: 'finance', isDefault: true),
    const Category(id: 'finance_savings', name: '적금/저축', emoji: '🏦', color: Color(0xFF607D8B), parentId: 'finance', isDefault: true),
    const Category(id: 'finance_interest', name: '이자비용', emoji: '📉', color: Color(0xFF607D8B), parentId: 'finance', isDefault: true),
    const Category(id: 'finance_crypto', name: '암호화폐', emoji: '🪙', color: Color(0xFF607D8B), parentId: 'finance', isDefault: true),

    // 👶 육아/자녀 하위
    const Category(id: 'child_daycare', name: '어린이집/유치원', emoji: '🏫', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),
    const Category(id: 'child_clothes', name: '아이옷', emoji: '👶', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),
    const Category(id: 'child_toys', name: '장난감', emoji: '🧸', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),
    const Category(id: 'child_baby', name: '유아용품', emoji: '🍼', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),
    const Category(id: 'child_academy', name: '아이학원/과외', emoji: '📝', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),
    const Category(id: 'child_hospital', name: '소아과', emoji: '👩‍⚕️', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),
    const Category(id: 'child_allowance', name: '용돈', emoji: '💵', color: Color(0xFFFFAB91), parentId: 'childcare', isDefault: true),

    // 🐾 반려동물 하위
    const Category(id: 'pet_food', name: '사료/간식', emoji: '🦴', color: Color(0xFFBCAAA4), parentId: 'pet', isDefault: true),
    const Category(id: 'pet_hospital', name: '동물병원', emoji: '🏥', color: Color(0xFFBCAAA4), parentId: 'pet', isDefault: true),
    const Category(id: 'pet_supplies', name: '반려용품', emoji: '🐾', color: Color(0xFFBCAAA4), parentId: 'pet', isDefault: true),
    const Category(id: 'pet_grooming', name: '미용', emoji: '✂️', color: Color(0xFFBCAAA4), parentId: 'pet', isDefault: true),
    const Category(id: 'pet_hotel', name: '펫호텔/돌봄', emoji: '🏨', color: Color(0xFFBCAAA4), parentId: 'pet', isDefault: true),

    // 🚙 자동차 하위
    const Category(id: 'car_maintenance', name: '정비/수리', emoji: '🔧', color: Color(0xFF78909C), parentId: 'car', isDefault: true),
    const Category(id: 'car_wash', name: '세차', emoji: '🚿', color: Color(0xFF78909C), parentId: 'car', isDefault: true),
    const Category(id: 'car_insurance', name: '자동차보험', emoji: '🛡️', color: Color(0xFF78909C), parentId: 'car', isDefault: true),
    const Category(id: 'car_tax', name: '자동차세', emoji: '📋', color: Color(0xFF78909C), parentId: 'car', isDefault: true),
    const Category(id: 'car_tire', name: '타이어', emoji: '⭕', color: Color(0xFF78909C), parentId: 'car', isDefault: true),
    const Category(id: 'car_accessory', name: '차량용품', emoji: '🪟', color: Color(0xFF78909C), parentId: 'car', isDefault: true),
    const Category(id: 'car_loan', name: '차량할부금', emoji: '💰', color: Color(0xFF78909C), parentId: 'car', isDefault: true),

    // 🛡️ 보험 하위
    const Category(id: 'ins_life', name: '생명보험', emoji: '❤️', color: Color(0xFF5C6BC0), parentId: 'insurance', isDefault: true),
    const Category(id: 'ins_health', name: '건강보험', emoji: '🏥', color: Color(0xFF5C6BC0), parentId: 'insurance', isDefault: true),
    const Category(id: 'ins_fire', name: '화재보험', emoji: '🔥', color: Color(0xFF5C6BC0), parentId: 'insurance', isDefault: true),
    const Category(id: 'ins_pension', name: '연금보험', emoji: '👴', color: Color(0xFF5C6BC0), parentId: 'insurance', isDefault: true),
    const Category(id: 'ins_child', name: '자녀보험', emoji: '👶', color: Color(0xFF5C6BC0), parentId: 'insurance', isDefault: true),
    const Category(id: 'ins_travel', name: '여행자보험', emoji: '✈️', color: Color(0xFF5C6BC0), parentId: 'insurance', isDefault: true),

    // 🏛️ 세금/공과금 하위
    const Category(id: 'tax_income', name: '소득세', emoji: '💵', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),
    const Category(id: 'tax_property', name: '재산세', emoji: '🏠', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),
    const Category(id: 'tax_resident', name: '주민세', emoji: '🏘️', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),
    const Category(id: 'tax_national', name: '국민연금', emoji: '🇰🇷', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),
    const Category(id: 'tax_health', name: '건강보험료', emoji: '🏥', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),
    const Category(id: 'tax_employment', name: '고용보험료', emoji: '🏢', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),
    const Category(id: 'tax_vat', name: '부가가치세', emoji: '📊', color: Color(0xFF8D6E63), parentId: 'tax', isDefault: true),

    // 📦 기타 하위
    const Category(id: 'other_misc', name: '기타지출', emoji: '📦', color: Color(0xFFBDC3C7), parentId: 'other_expense', isDefault: true),
    const Category(id: 'other_atm', name: 'ATM현금인출', emoji: '🏧', color: Color(0xFFBDC3C7), parentId: 'other_expense', isDefault: true),
    const Category(id: 'other_fine', name: '벌금/과태료', emoji: '⚠️', color: Color(0xFFBDC3C7), parentId: 'other_expense', isDefault: true),
    const Category(id: 'other_loss', name: '분실/도난', emoji: '😢', color: Color(0xFFBDC3C7), parentId: 'other_expense', isDefault: true),
  ];

  // ============================================================
  // 수입 카테고리 (Income Categories)
  // ============================================================
  static List<Category> get incomeCategories => [
    const Category(
      id: 'income_salary',
      name: '월급',
      emoji: '💵',
      color: Color(0xFF22C55E),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_bonus',
      name: '상여금',
      emoji: '🎁',
      color: Color(0xFF16A34A),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_allowance',
      name: '수당',
      emoji: '💰',
      color: Color(0xFF059669),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_overtime',
      name: '야근수당',
      emoji: '🌙',
      color: Color(0xFF047857),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_freelance',
      name: '프리랜서수입',
      emoji: '💻',
      color: Color(0xFF0D9488),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_business',
      name: '사업소득',
      emoji: '🏢',
      color: Color(0xFF0891B2),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_investment',
      name: '투자수익',
      emoji: '📈',
      color: Color(0xFF15803D),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_dividend',
      name: '배당금',
      emoji: '📊',
      color: Color(0xFF166534),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_interest',
      name: '이자수익',
      emoji: '🏦',
      color: Color(0xFF047857),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_rental',
      name: '임대소득',
      emoji: '🏠',
      color: Color(0xFF0D9488),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_side',
      name: '부수입',
      emoji: '💼',
      color: Color(0xFF059669),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_pension',
      name: '연금',
      emoji: '👴',
      color: Color(0xFF0891B2),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_refund',
      name: '환급금',
      emoji: '💸',
      color: Color(0xFF14B8A6),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_pocket',
      name: '용돈',
      emoji: '💝',
      color: Color(0xFF34D399),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_gift',
      name: '선물금/축의금',
      emoji: '🎊',
      color: Color(0xFF6EE7B7),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_scholarship',
      name: '장학금',
      emoji: '🎓',
      color: Color(0xFF10B981),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_resale',
      name: '중고판매',
      emoji: '🛍️',
      color: Color(0xFF2DD4BF),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_lottery',
      name: '로또/복권',
      emoji: '🎰',
      color: Color(0xFF4ADE80),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_insurance',
      name: '보험금수령',
      emoji: '🛡️',
      color: Color(0xFF86EFAC),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_retirement',
      name: '퇴직금',
      emoji: '🏖️',
      color: Color(0xFF059669),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_government',
      name: '정부지원금',
      emoji: '🏛️',
      color: Color(0xFF047857),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_child',
      name: '아동수당',
      emoji: '👶',
      color: Color(0xFF34D399),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_crypto',
      name: '암호화폐수익',
      emoji: '🪙',
      color: Color(0xFF10B981),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_youtube',
      name: '유튜브/SNS수익',
      emoji: '📱',
      color: Color(0xFF22C55E),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_inheritance',
      name: '상속/증여',
      emoji: '📜',
      color: Color(0xFF16A34A),
      isDefault: true,
      type: TransactionType.income,
    ),
    const Category(
      id: 'income_other',
      name: '기타수입',
      emoji: '📥',
      color: Color(0xFF10B981),
      isDefault: true,
      type: TransactionType.income,
    ),
  ];

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Get all expense categories (parents + subcategories)
  static List<Category> get allExpenseCategories => [
    ...expenseParentCategories,
    ...expenseSubcategories,
  ];

  /// Get all categories (for backward compatibility)
  static List<Category> get defaultCategories => [
    ...expenseParentCategories,
    ...incomeCategories,
  ];

  /// Get all categories including subcategories
  static List<Category> get allCategories => [
    ...expenseParentCategories,
    ...expenseSubcategories,
    ...incomeCategories,
  ];

  /// Get subcategories for a parent category
  static List<Category> getSubcategories(String parentId) {
    return expenseSubcategories
        .where((c) => c.parentId == parentId)
        .toList();
  }

  /// Get parent category for a subcategory
  static Category? getParentCategory(String subcategoryId) {
    final subcategory = expenseSubcategories.firstWhere(
      (c) => c.id == subcategoryId,
      orElse: () => const Category(id: '', name: '', emoji: '', color: Colors.grey),
    );
    if (subcategory.parentId == null) return null;
    return expenseParentCategories.firstWhere(
      (c) => c.id == subcategory.parentId,
      orElse: () => const Category(id: '', name: '', emoji: '', color: Colors.grey),
    );
  }

  /// Find category by ID
  static Category? findById(String id) {
    return allCategories.cast<Category?>().firstWhere(
      (c) => c?.id == id,
      orElse: () => null,
    );
  }

  /// Find category by name
  static Category findByName(String name) {
    return allCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => expenseParentCategories.last,
    );
  }

  /// OCR 서버 응답 카테고리를 앱 카테고리 이름으로 매칭
  /// Gemini가 '의료'를 반환하면 '건강/의료'로 매칭하는 등의 퍼지 매칭 수행
  static String matchOcrCategory(String ocrCategory, {bool isIncome = false}) {
    final input = ocrCategory.trim();
    if (input.isEmpty) return '기타';

    // 1) 정확히 일치하는 카테고리가 있으면 바로 반환
    final categories = isIncome ? incomeCategories : [...expenseParentCategories, ...expenseSubcategories];
    for (final c in categories) {
      if (c.name == input) return c.name;
    }

    // 2) 부분 매칭: OCR 결과가 카테고리 이름에 포함되거나, 카테고리 이름이 OCR 결과에 포함
    for (final c in categories) {
      // '의료' → '건강/의료', '미용' → '의류/미용' 등
      if (c.name.contains(input) || input.contains(c.name)) {
        // 소분류면 대분류 이름 반환
        if (c.isSubcategory) {
          final parent = getParentCategory(c.id);
          return parent?.name ?? c.name;
        }
        return c.name;
      }
    }

    // 3) '/' 로 분리된 카테고리 부분 매칭 (건강/의료, 의류/미용, 여가/문화 등)
    for (final c in expenseParentCategories) {
      final parts = c.name.split('/');
      for (final part in parts) {
        if (part == input) return c.name;
      }
    }

    // 4) 키워드 기반 매칭
    final keywordMap = <String, String>{
      '병원': '건강/의료', '약국': '건강/의료', '의원': '건강/의료', '치과': '건강/의료',
      '안과': '건강/의료', '피부과': '건강/의료', '한의원': '건강/의료', '헬스': '건강/의료',
      '카페': '식비', '커피': '식비', '편의점': '식비', '식당': '식비', '음식': '식비',
      '배달': '식비', '치킨': '식비', '피자': '식비', '빵': '식비',
      '마트': '생활용품', '다이소': '생활용품',
      '옷': '의류/미용', '신발': '의류/미용', '화장품': '의류/미용', '미용실': '의류/미용',
      '영화': '여가/문화', '공연': '여가/문화', '여행': '여가/문화', '서점': '여가/문화',
      '주유': '교통비', '택시': '교통비', '버스': '교통비', '지하철': '교통비',
      '학원': '교육', '등록금': '교육', '강의': '교육',
      '보험': '보험', '세금': '세금/공과금', '공과금': '세금/공과금',
      '대출': '금융', '수수료': '금융', '투자': '금융',
    };
    for (final entry in keywordMap.entries) {
      if (input.contains(entry.key)) return entry.value;
    }

    return isIncome ? '기타수입' : '기타';
  }

  /// Get categories by type
  static List<Category> getCategoriesByType(TransactionType type) {
    if (type == TransactionType.income) {
      return incomeCategories;
    }
    return expenseParentCategories;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color': color.toARGB32(),
      'isDefault': isDefault ? 1 : 0,
      'parentId': parentId,
      'type': type.index,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      color: Color(map['color'] as int),
      isDefault: map['isDefault'] == 1,
      parentId: map['parentId'] as String?,
      type: TransactionType.values[map['type'] as int? ?? 0],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category($id, $name, $emoji)';
}
