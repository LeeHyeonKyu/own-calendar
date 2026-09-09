import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HolidaySettingsScreen extends StatefulWidget {
  const HolidaySettingsScreen({super.key});

  @override
  State<HolidaySettingsScreen> createState() => _HolidaySettingsScreenState();
}

class _HolidaySettingsScreenState extends State<HolidaySettingsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<String> _subscribedCountries = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _countries = <String, String>{
    'KR': '한국',
    'US': '미국',
    'JP': '일본',
    'CN': '중국',
    'GB': '영국',
    'DE': '독일',
    'FR': '프랑스',
    'CA': '캐나다',
    'AU': '호주',
    'IN': '인도',
    'BR': '브라질',
    'MX': '멕시코',
    'IT': '이탈리아',
    'ES': '스페인',
    'NL': '네덜란드',
    'SE': '스웨덴',
    'NO': '노르웨이',
    'DK': '덴마크',
    'FI': '핀란드',
    'CH': '스위스',
    'AT': '오스트리아',
    'BE': '벨기에',
    'PL': '폴란드',
    'PT': '포르투갈',
    'SG': '싱가포르',
    'TW': '대만',
    'TH': '태국',
    'VN': '베트남',
    'PH': '필리핀',
    'ID': '인도네시아',
    'MY': '말레이시아',
    'NZ': '뉴질랜드',
    'IE': '아일랜드',
    'ZA': '남아프리카',
    'RU': '러시아',
    'TR': '튀르키예',
    'AR': '아르헨티나',
    'CL': '칠레',
    'CO': '콜롬비아',
    'PE': '페루',
  };

  static const _countryFlags = <String, String>{
    'KR': '\u{1F1F0}\u{1F1F7}',
    'US': '\u{1F1FA}\u{1F1F8}',
    'JP': '\u{1F1EF}\u{1F1F5}',
    'CN': '\u{1F1E8}\u{1F1F3}',
    'GB': '\u{1F1EC}\u{1F1E7}',
    'DE': '\u{1F1E9}\u{1F1EA}',
    'FR': '\u{1F1EB}\u{1F1F7}',
    'CA': '\u{1F1E8}\u{1F1E6}',
    'AU': '\u{1F1E6}\u{1F1FA}',
    'IN': '\u{1F1EE}\u{1F1F3}',
    'BR': '\u{1F1E7}\u{1F1F7}',
    'MX': '\u{1F1F2}\u{1F1FD}',
    'IT': '\u{1F1EE}\u{1F1F9}',
    'ES': '\u{1F1EA}\u{1F1F8}',
    'NL': '\u{1F1F3}\u{1F1F1}',
    'SE': '\u{1F1F8}\u{1F1EA}',
    'NO': '\u{1F1F3}\u{1F1F4}',
    'DK': '\u{1F1E9}\u{1F1F0}',
    'FI': '\u{1F1EB}\u{1F1EE}',
    'CH': '\u{1F1E8}\u{1F1ED}',
    'AT': '\u{1F1E6}\u{1F1F9}',
    'BE': '\u{1F1E7}\u{1F1EA}',
    'PL': '\u{1F1F5}\u{1F1F1}',
    'PT': '\u{1F1F5}\u{1F1F9}',
    'SG': '\u{1F1F8}\u{1F1EC}',
    'TW': '\u{1F1F9}\u{1F1FC}',
    'TH': '\u{1F1F9}\u{1F1ED}',
    'VN': '\u{1F1FB}\u{1F1F3}',
    'PH': '\u{1F1F5}\u{1F1ED}',
    'ID': '\u{1F1EE}\u{1F1E9}',
    'MY': '\u{1F1F2}\u{1F1FE}',
    'NZ': '\u{1F1F3}\u{1F1FF}',
    'IE': '\u{1F1EE}\u{1F1EA}',
    'ZA': '\u{1F1FF}\u{1F1E6}',
    'RU': '\u{1F1F7}\u{1F1FA}',
    'TR': '\u{1F1F9}\u{1F1F7}',
    'AR': '\u{1F1E6}\u{1F1F7}',
    'CL': '\u{1F1E8}\u{1F1F1}',
    'CO': '\u{1F1E8}\u{1F1F4}',
    'PE': '\u{1F1F5}\u{1F1EA}',
  };

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/holidays');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        _subscribedCountries =
            data.map((s) => s['countryCode'] as String).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleCountry(String countryCode) async {
    final isSubscribed = _subscribedCountries.contains(countryCode);

    // Optimistic update
    setState(() {
      if (isSubscribed) {
        _subscribedCountries.remove(countryCode);
      } else {
        _subscribedCountries.add(countryCode);
      }
    });

    try {
      if (isSubscribed) {
        await _api.delete('/holidays/subscribe/$countryCode');
      } else {
        await _api.post('/holidays/subscribe', {'countryCode': countryCode});
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          if (isSubscribed) {
            _subscribedCountries.add(countryCode);
          } else {
            _subscribedCountries.remove(countryCode);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경에 실패했습니다')),
        );
      }
    }
  }

  List<MapEntry<String, String>> get _filteredCountries {
    final entries = _countries.entries.toList();
    if (_searchQuery.isEmpty) return entries;
    final query = _searchQuery.toLowerCase();
    return entries
        .where((e) =>
            e.value.toLowerCase().contains(query) ||
            e.key.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCountries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('공휴일 설정'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '국가 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (_subscribedCountries.isNotEmpty && _searchQuery.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '구독 중',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final isSubscribed =
                      _subscribedCountries.contains(entry.key);
                  final flag = _countryFlags[entry.key] ?? '';

                  return SwitchListTile(
                    secondary: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text(entry.value),
                    subtitle: Text(entry.key),
                    value: isSubscribed,
                    onChanged: (_) => _toggleCountry(entry.key),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
