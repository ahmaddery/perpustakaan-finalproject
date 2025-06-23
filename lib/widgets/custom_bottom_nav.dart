import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../widgets/notification_badge.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String currentLanguage;

  const CustomBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.currentLanguage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.dashboard_rounded,
            label: LocalizationService.getText('dashboard', currentLanguage),
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.library_books_rounded,
            label: LocalizationService.getText('book_collection', currentLanguage),
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.people_rounded,
            label: currentLanguage == 'id' ? 'Anggota' : 'Members',
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.assignment_rounded,
            label: currentLanguage == 'id' ? 'Peminjaman' : 'Loans',
          ),
          _buildNavItemWithBadge(
            index: 4,
            icon: Icons.notifications_rounded,
            label: currentLanguage == 'id' ? 'Notifikasi' : 'Notifications',
          ),
          _buildNavItem(
            index: 5,
            icon: Icons.settings_rounded,
            label: LocalizationService.getText('settings', currentLanguage),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.blue[600] : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue[600] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? Colors.blue[600] : Colors.grey[500],
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: NotificationBadge(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue[600] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}