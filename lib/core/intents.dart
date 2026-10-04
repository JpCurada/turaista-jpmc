/// Fixed guest-message intent taxonomy (see .claude/skills/intent-taxonomy).
library;

enum GuestIntent {
  booking('BOOKING'),
  price('PRICE'),
  directions('DIRECTIONS'),
  dietarySafety('DIETARY_SAFETY'),
  other('OTHER');

  const GuestIntent(this.code);

  final String code;
}

// Keyword patterns are regular expressions, matched case-insensitively.
// Latin-script words are anchored with \b so they match whole words or word
// stems only: 'fee' must not match "coffee", 'book' must not match "Facebook".
// Korean, Japanese and Chinese have no spaces, so those match anywhere; a
// lookaround keeps a short word out of longer ones (아이 but not 아이스).
// When a word is ambiguous, list it under a blocked intent: a missed safety
// question is the worst failure in this app.

const List<String> _safety = [
  // English: diet and allergies (stems also catch common typos)
  r'\ba?l+erg', r'\bvegan', r'\bveg[ei]t', r'\bveggie', r'\bhalal\b', r'\bkosher\b',
  r'\bmuslim', r'\bgluten', r'\bceliac', r'\bcoeliac', r'\bintoleran', r'\blactose',
  r'\bdairy\b', r'\bmilk\b', r'\beggs?\b', r'\bwheat\b', r'\bsoy', r'\bsesame\b', r'\bnuts?\b',
  r'\bpeanut', r'\bshellfish\b', r'\bshrimps?\b', r'\bfish\b', r'\bseafood\b', r'\bchicken\b',
  r'\b(crab|squid|tuna|salmon|lobster|oyster)s?\b', r'\bpescatarian',
  r'\bdiet', r'\bingredient', r'\bmeat\b', r'\bpork\b', r'\bbeef\b',
  // English: health and body
  r'\bdiabet', r'\bmedic', r'\basthma', r'\bepilep', r'\bheart\b', r'\bblood pressure\b',
  r'\bcancer\b', r'\barthritis\b', r'\bknees?\b', r'\bback pain\b', r'\bsick', r'\bill\b',
  r'\bpregn', r'\bstrenuous\b', r'\bhow hard\b', r'\bsteep\b', r'\bslippery\b',
  // English: children, older people, family members who may need care
  r'\btoddler', r'\bbab(y|ies)\b', r'\binfant', r'\bkids?\b', r'\bchil?d', r'\bchilren\b',
  r'\bstroller',
  r'\bpram\b',
  r'\b\d+\s*-?\s*(years?|yrs?|months?)[\s-]*old\b',
  r'\b\d+\s*y/?o\b',
  r'\byears?[\s-]old\b',
  r'\bages?\b', r'\baged\b',
  r'\bgrand(ma|pa|mother|father|parents?|son|daughter)', r'\b(mom|mum|mother|dad|father)\b',
  r'\bparents?\b', r'\bson\b', r'\bdaughter', r'\belder', r'\bseniors?\b', r'\bolder\b',
  r'\bold (people|folks)\b', r'\bfamily\b', r'\bin-laws?\b', r'\bteen',
  r'\b(wife|husband|aunt|uncle|sister|brother|niece|nephew|cousin|boy|girl)s?\b',
  // English: mobility and danger
  r'\bwheel[\s-]?chair', r'\bwalker\b', r'\bcrutch', r'\bcane\b', r'\bmobility\b',
  r'\bdisab', r'\bhandicap', r'\bspecial needs\b', r'\bsafe', r'\bdanger', r'\binjur',
  // Tagalog
  r'\bbata\b', r'\bmga bata\b', r'\banak\b', r'\bsanggol\b', r'\bbuntis\b', r'\bligtas\b',
  r'\bdelikado\b', r'\bgamot\b', r'\bsakit\b', r'\bmatanda\b', r'\bmatatanda\b', r'\blolo\b',
  r'\blola\b', r'\bpwd\b', r'\bkarne\b', r'\bbaboy\b', r'\bmanok\b', r'\bisda\b',
  r'\bgatas\b', r'\bitlog\b', r'\bhipon\b', r'\bmani\b', r'\bkeso\b', r'\bbawal\b',
  r"\bcan'?t eat\b", r'\bcannot eat\b', r'\bcheese\b', r'\bpacemaker',
  r'\btaon\b', r'\bgulang\b', r'\bmagulang\b', r'\bpamilya\b',
  // Korean
  '알레르기', '알러지', '채식', '비건', '할랄', '무슬림', '글루텐', '견과', '땅콩', '갑각류', '새우',
  '해산물', '생선', '계란', '달걀', '우유', '고기', '당뇨', '혈압', '천식', '임신', '장애', '휠체어',
  '무릎', '몸이 불편', '유모차', '아이(?!스|디|템)', '애들', '아기', '어린이', '유아', r'\d+\s*살',
  '아들', '딸(?!기)', '엄마', '아빠', '부모', '노인', '어르신', '할머니', '할아버지', '손자', '손녀',
  '안전', '위험', '약물', '가족', r'\d+\s*세', '개월',
  // Japanese
  'アレルギー', 'ベジタリアン', 'ヴィーガン', 'ビーガン', '菜食', 'ハラー?ル', 'ムスリム', 'グルテン',
  'ナッツ', '甲殻類', 'えび', 'エビ', '卵', '乳製品', '牛乳', '小麦', '豚', '肉', '糖尿', '喘息',
  '病気', '持病', '体調', '薬', '妊娠', '妊婦', '車椅子', '車いす', '杖', '膝', '食事制限',
  '子供', '子ども', 'こども', '赤ちゃん', '幼児', 'ベビーカー', r'\d+\s*[歳才]', '息子', '娘', '孫',
  '母', '父', 'おばあ', 'おじい', '祖母', '祖父', '高齢', 'お年寄り', '安全', '危険',
  '魚', '鶏', 'アレルゲン', '家族', 'ヶ月',
  // Chinese (simplified and traditional)
  '过敏', '過敏', '素食', '吃素', '清真', '穆斯林', '麸质', '坚果', '堅果', '花生', '海鲜', '海鮮',
  '鸡蛋', '雞蛋', '牛奶', '猪肉', '豬肉', '牛肉', '糖尿', '高血压', '高血壓', '心脏', '心臟', '哮喘',
  '病', '药', '藥', '怀孕', '懷孕', '孕妇', '孕婦', '轮椅', '輪椅', '残疾', '殘疾', '行动不便',
  '行動不便', '腿脚', '孩子', '小孩', '小朋友', '儿童', '兒童', '婴儿', '嬰兒', '宝宝', '寶寶',
  '推车', '推車', r'\d+\s*[岁歲]', '女儿', '女兒', '儿子', '兒子', '妈妈', '媽媽', '爸爸', '外婆',
  '外公', '老人', '奶奶', '爷爷', '爺爺', '长辈', '長輩', '安全', '危险', '危險',
  '鱼', '蛋', '家人', '一家', '个月', '個月',
];

/// Topics the farm profile does not cover. A match adds OTHER even when an
/// allowed intent is also present, so the whole message is blocked instead of
/// half answered ("Can we bring our dog? How much is it?").
const List<String> _outOfProfile = [
  r'\bdogs?\b', r'\bpets?\b', r'\bhorses?\b', r'\bcamp', r'\btents?\b', r'\bovernight\b',
  r'\bstay (overnight|the night)\b', r'\bhotel', r'\bhomestay', r'\blodging\b',
  r'\baccommodation', r'\bparking\b', r'\bpark (our|the|my) car\b', r'\btoilet', r'\brestroom',
  r'\bbathroom', r'\bswim', r'\bbring (our own |my own |)food\b', r'\bpick (us|me) up\b',
  r'\bpick-?up\b', r'\bshuttle', r'\btransfer\b', r'\brefund', r'\bcancel', r'\breschedul',
  r'\bpostpon', r'\binsurance\b', r'\bnights?\b', r'\bsleep',
  // places and services outside the farm ("how far is the nearest hospital?")
  r'\bnearest\b', r'\bhospital', r'\bclinic', r'\bpharmac', r'\batm\b', r'\bairport',
  r'\bterminal\b', r'\btaxi', r'\bgrab\b', r'\bbus(es)?\b', r'\bvan\b', r'\brestaurant',
  r'\bguides?\b', r'\bcharg(er|ing)\b',
  // payment methods and terms (the profile only has prices)
  r'\bpay (online|by|with|via|in|through)\b',
  r'\bhow (to|do i|do we|can i|can we) pay\b',
  r'\bpayment',
  r'\bdeposit',
  r'\bcredit card',
  r'\bcards?\b', r'\bcash\b', r'\bgcash\b', r'\bmaya\b', r'\bpaypal\b', r'\bvisa\b',
  r'\bmastercard\b', r'\balipay\b', r'\bwechat\b', r'\bkakao ?pay\b', r'\bpaypay\b',
  r'\bwi-?fi\b', r'\bdrones?\b', r'\bsmok', r'\balcohol', r'\bbeer\b', r'\bwine\b',
  r'\bsouvenir', r'\bdiscount', r'\brain', r'\btyphoon', r'\bweather\b',
  // Korean ('비가' only as its own word: not 준비가 or 소비가)
  '주차', '화장실', '환불', '취소', '일정 변경', '카드', '결제', '현금', '계좌', '입금', '반려', '강아지',
  '캠핑', '숙박', '숙소', '픽업', '와이파이', '드론', '흡연', '할인', '(?<![가-힣])비 ?(가|오|올)', '우천',
  '날씨', '태풍', '호텔', '병원', '약국', '공항', '택시', '버스', '가이드', '식당',
  // Japanese
  '駐車', 'トイレ', '返金', 'キャンセル', 'カード', '支払', '現金', '振込', '送迎', 'ペット', '犬',
  'キャンプ', '宿泊', 'ドローン', '喫煙', '割引', '雨', '天気', '台風', 'ホテル', '病院', '薬局', '空港',
  'タクシー', 'バス', 'ガイド', 'レストラン',
  // Chinese
  '停车', '停車', '厕所', '廁所', '洗手间', '洗手間', '退款', '取消', '改期', '信用卡', '刷卡', '付款',
  '支付', '微信', '定金', '订金', '押金', '现金', '現金', '接送', '宠物', '寵物', '狗', '露营', '露營',
  '住宿', '无人机', '無人機', '吸烟', '抽烟', '折扣', '下雨', '天气', '天氣', '台风',
  '酒店', '医院', '醫院', '药店', '机场', '機場', '出租车', '打车', '巴士', '公交', '导游', '導遊', '餐厅',
  '餐廳',
];

const List<(GuestIntent, List<String>)> _keywords = [
  (GuestIntent.dietarySafety, _safety),
  (GuestIntent.other, _outOfProfile),
  (
    GuestIntent.price,
    [
      r'\bpric',
      r'\bcosts?\b',
      r'\bfees?\b',
      r'\brates?\b',
      r'\bhow much\b',
      r'\bper person\b',
      r'\bentrance\b',
      r'\btickets?\b',
      r'\bpesos?\b',
      r'\bcharge',
      r'\bmagkano\b',
      r'\bpresyo\b',
      r'\bbayad\b',
      r'\bfree\b',
      '무료',
      '無料',
      '免费',
      '免費',
      '가격',
      '얼마',
      '요금',
      '비용',
      '입장료',
      '料金',
      'いくら',
      '値段',
      '費用',
      '代金',
      'ツアー代',
      '入場料',
      '多少钱',
      '多少錢',
      '价格',
      '價格',
      '价钱',
      '费用',
      '票价',
      '門票',
      '门票',
      '收费',
      '收費',
    ],
  ),
  (
    GuestIntent.booking,
    [
      r'\bbook',
      r'\breserv',
      r'\bavailab',
      r'\bvisit on\b',
      r'\bslots?\b',
      r'\bopen on\b',
      r'\bgroup of\b',
      r'\breserba',
      r'\bpa-?book',
      '예약',
      '방문(하|해|할|가능|예정)',
      '予約',
      '预订',
      '預訂',
      '预约',
      '預約',
    ],
  ),
  (
    GuestIntent.directions,
    [
      r'\bdirections?\b',
      r'\bhow (do|can) (we|i) get\b',
      r'\bhow to get\b',
      r'\bget to (the|your) (farm|place)\b',
      r'\bwhere is\b',
      r'\bwhere.?s the farm\b',
      r'\bwhere are you\b',
      r'\blocated\b',
      r'\blocation\b',
      r'\baddress\b',
      r'\bhow far (is|to) (the |your )?(farm|place)',
      r'\bjeepney',
      r'\blandmark',
      r'\bpaano pumunta\b',
      '어떻게 가',
      '가는 길',
      '위치',
      '주소',
      '行き方',
      '道順',
      'アクセス',
      '場所',
      '住所',
      '怎么去',
      '怎麼去',
      '怎么走',
      '路线',
      '路線',
      '地址',
      '位置',
    ],
  ),
];

final List<(GuestIntent, List<RegExp>)> _compiled = [
  for (final (intent, patterns) in _keywords)
    (intent, [for (final p in patterns) RegExp(p, caseSensitive: false)]),
];

Set<GuestIntent> _match(String text) => {
  for (final (intent, patterns) in _compiled)
    if (patterns.any((p) => p.hasMatch(text))) intent,
};

/// Clause breaks: ! ? 。 ！ ？ ， 、 and line breaks; a period only before a space
/// and a capital or CJK letter (so "3 p.m." and "1.5" stay whole); spaces
/// between Chinese or Japanese characters, which do not use spaces otherwise;
/// and Korean sentence endings.
final RegExp _clauseBreak = RegExp(
  r'(?<=[!?。！？，、\n])'
  r'|(?<=\.)(?=\s+[A-Z\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af])'
  r'|(?<=[\u3040-\u30ff\u4e00-\u9fff])\s+(?=[\u3040-\u30ff\u4e00-\u9fff])'
  // Korean spaces words, so split only after a sentence ending (\u2026\uc694, \u2026\uae4c, \u2026\ub2c8, \u2026\uc8e0).
  r'|(?<=[\uc694\uae4c\ub2c8\uc8e0])\s+(?=[\uac00-\ud7af])',
);

/// Trailing quotes, brackets, emoji and other punctuation hide a question mark.
final RegExp _trailingNoise = RegExp(r'[^\p{L}\p{N}?？]+$', unicode: true);

/// A question: ends in ? or ？, ends like a Korean, Japanese or Chinese
/// question even without a mark, or starts with an English or Tagalog
/// question word. Over-counting only blocks more, which is the safe side.
final RegExp _questionShape = RegExp(
  r'[?？]$|(까요?|나요|가요|니|냐|죠|か|かな|吗|嗎|呢)$'
  r'|^(do|does|did|can|could|is|are|was|will|would|what|when|where|which|who|how|may|'
  r'should|pwede|puwede|ano|saan|paano|kailan|meron)\b',
  caseSensitive: false,
);

/// Offline keyword baseline. Used as a fallback and as a test oracle for any
/// small-model classifier.
///
/// Returns every matching intent, or {GuestIntent.other} if nothing matches.
/// Each question (see [_questionShape]) must match some intent on its own; a
/// question the keywords cannot place adds OTHER, so a side question the
/// profile cannot answer blocks the message instead of being dropped.
Set<GuestIntent> classifyKeywords(String text) {
  final signals = keywordSignals(text);
  final found = {...signals.matched};
  if (signals.unplacedQuestion) found.add(GuestIntent.other);
  return found.isEmpty ? {GuestIntent.other} : found;
}

/// What the keywords saw: the intents whose words appear in [text], and
/// whether some question in it matched no intent words at all.
typedef KeywordSignals = ({Set<GuestIntent> matched, bool unplacedQuestion});

KeywordSignals keywordSignals(String text) {
  var unplaced = false;
  for (final clause in text.split(_clauseBreak)) {
    final c = clause.trim().replaceFirst(_trailingNoise, '');
    if (_questionShape.hasMatch(c) && _match(c).isEmpty) unplaced = true;
  }
  return (matched: _match(text), unplacedQuestion: unplaced);
}
