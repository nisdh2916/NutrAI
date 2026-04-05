import 'package:flutter/material.dart';

// ── 추천 음식 카드 모델 ──────────────────────────
class RecommendItem {
  final String id;
  final String name;
  final List<String> tags;
  final String description;
  final Color placeholderColor; // 실제 앱에서는 imageUrl
  final double kcal;
  final double carb;
  final double protein;
  final double fat;
  bool isFavorite;

  RecommendItem({
    required this.id,
    required this.name,
    required this.tags,
    required this.description,
    required this.placeholderColor,
    required this.kcal,
    required this.carb,
    required this.protein,
    required this.fat,
    this.isFavorite = false,
  });
}

// ── 피드백 사유 ──────────────────────────────────
const List<String> feedbackReasons = [
  '좋아하지 않는 음식이라서',
  '음식 재료가 없어서',
  '가격이 부담스러워서',
  '해당 음식이 자주 추천돼서',
  '싫어하는 재료가 들어있어서',
  '조리 난이도가 높아져서',
  '기타',
];

// ── 샘플 추천 데이터 ─────────────────────────────
class RecommendSampleData {
  static List<RecommendItem> get preference => [
    RecommendItem(
      id: 'p1',
      name: '리코타 치즈 샐러드',
      tags: ['#식단', '#건강X', '#건강식단'],
      description: '신선한 채소와 리코타 치즈가 어우러진 가볍고 건강한 샐러드예요. 단백질과 식이섬유가 풍부해 다이어트에 최적이에요.',
      placeholderColor: const Color(0xFFF0E6D3),
      kcal: 280, carb: 22, protein: 14, fat: 16,
    ),
    RecommendItem(
      id: 'p2',
      name: '양송이 스프',
      tags: ['#간식', '#다이어트', '#간식식단'],
      description: '크리미한 양송이 스프로 포만감 있게 즐겨보세요. 저칼로리로 식사 전 공복을 달래기에 딱이에요.',
      placeholderColor: const Color(0xFFE8DFD0),
      kcal: 150, carb: 12, protein: 6, fat: 8,
    ),
    RecommendItem(
      id: 'p3',
      name: '감자볶음',
      tags: ['#간식식품', '#식녀눈', '#다이어트'],
      description: '간단한 재료로 만드는 국민 반찬! 적당한 탄수화물로 에너지를 보충하세요.',
      placeholderColor: const Color(0xFFF5E8C0),
      kcal: 190, carb: 35, protein: 4, fat: 5,
    ),
    RecommendItem(
      id: 'p4',
      name: '닭가슴살 볼',
      tags: ['#단백질', '#근육증진', '#저지방'],
      description: '고단백 저지방의 대표 식재료, 닭가슴살로 만든 간편 영양 볼이에요.',
      placeholderColor: const Color(0xFFE0EDD8),
      kcal: 220, carb: 8, protein: 35, fat: 6,
    ),
    RecommendItem(
      id: 'p5',
      name: '두부 된장찌개',
      tags: ['#한식', '#저칼로리', '#국물'],
      description: '구수한 된장과 두부의 조화. 낮은 칼로리에도 포만감이 오래 지속돼요.',
      placeholderColor: const Color(0xFFDDE8F0),
      kcal: 130, carb: 10, protein: 12, fat: 4,
    ),
  ];

  static List<RecommendItem> get today => [
    RecommendItem(
      id: 't1',
      name: '오늘의 추천: 그릭 요거트볼',
      tags: ['#아침추천', '#단백질', '#건강식'],
      description: '오늘 단백질 섭취가 부족해요. 그릭 요거트에 견과류와 꿀을 올린 영양 만점 아침 식사를 추천해요.',
      placeholderColor: const Color(0xFFF5EDE8),
      kcal: 310, carb: 28, protein: 22, fat: 12,
    ),
    RecommendItem(
      id: 't2',
      name: '점심 추천: 닭가슴살 샐러드',
      tags: ['#점심추천', '#고단백', '#저탄'],
      description: '오늘 탄수화물 섭취가 이미 목표의 70%예요. 저탄고단 식사로 균형을 맞춰보세요.',
      placeholderColor: const Color(0xFFDEF0E4),
      kcal: 340, carb: 18, protein: 40, fat: 10,
    ),
    RecommendItem(
      id: 't3',
      name: '저녁 추천: 된장찌개 정식',
      tags: ['#저녁추천', '#한식', '#균형식단'],
      description: '오늘 나트륨이 약간 부족해요. 된장찌개와 채소 반찬으로 하루를 마무리해보세요.',
      placeholderColor: const Color(0xFFE8EEF5),
      kcal: 480, carb: 65, protein: 25, fat: 14,
    ),
  ];
}
