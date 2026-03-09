// lib/features/home/presentation/pages/shell_widgets.dart
//
// Shared UI primitives used by AdminShellPage, DoctorShellPage
// and NurseShellPage.  Keep presentation-only — no business logic.

import 'package:flutter/material.dart';

const Color kPrimaryGreen = Color(0xFF1B4332);
const Color kBgSlate      = Color(0xFFF8FAFC);

// ─── Bottom navigation bar ───────────────────────────────────────────────────

class ShellNavItem {
  final IconData filled;
  final IconData outline;
  final String   label;
  const ShellNavItem(this.filled, this.outline, this.label);
}

class ShellBottomNav extends StatelessWidget {
  final List<ShellNavItem> items;
  final int                current;
  final void Function(int) onTap;
  final Color              color;

  const ShellBottomNav({
    super.key,
    required this.items,
    required this.current,
    required this.onTap,
    this.color = kPrimaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = current == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: color.withOpacity(0.08),
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        sel ? items[i].filled : items[i].outline,
                        color: sel ? color : Colors.grey[400],
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? color : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Role badge chip ─────────────────────────────────────────────────────────

class RoleBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const RoleBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Dashboard header card ───────────────────────────────────────────────────

class DashboardHeaderCard extends StatelessWidget {
  final String name;
  final String facility;
  final String roleLabel;
  final Color  roleColor;

  const DashboardHeaderCard({
    super.key,
    required this.name,
    required this.facility,
    required this.roleLabel,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54, fontSize: 10, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: roleColor.withOpacity(0.9),
                      fontSize: 10, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat card ───────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color   color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Action row tile ─────────────────────────────────────────────────────────

class ActionRow extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        color;
  final VoidCallback onTap;

  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey,
        ),
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A),
      ),
    );
  }
}