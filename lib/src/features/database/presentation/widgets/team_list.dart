import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/team_controller.dart';
import '../../domain/team_member.dart';
import 'database_list.dart';
import 'team_card.dart';

/// What `Komanda` calls a row: an *əməkdaş* — the website's own word,
/// `Əməkdaş tapılmadı`.
const DatabaseListWords kTeamListWords = DatabaseListWords(
  unit: 'əməkdaş',
  checking: 'Əməkdaşlar yoxlanılır…',
  empty: 'Əməkdaş tapılmadı.',
  filteredEmpty: 'Filterə uyğun əməkdaş tapılmadı.',
);

/// `Komanda`: everyone on the staff register as a card, in the bridge's
/// order, fetched a page at a time as the list nears its end — or, while a
/// filter is on, the people it lets through. [DatabaseList] does the work;
/// this says what a card is.
class TeamList extends StatelessWidget {
  const TeamList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final TeamController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<TeamMember>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (TeamMember member) => member.id,
      words: kTeamListWords,
      // The design is `Müştərilər`' frame with a new card in it, and keeps
      // its cards 9pt apart.
      gap: 9,
      card: _card,
    );
  }

  /// The same card in either list: a person's card has nothing to open.
  static Widget _card(
    BuildContext context,
    DatabaseRows<TeamMember> rows,
    TeamMember member,
  ) => TeamCard(member: member);
}
