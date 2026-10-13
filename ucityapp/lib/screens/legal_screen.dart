import 'package:flutter/material.dart';

import '../theme.dart';

enum LegalPage { privacy, terms }

const _privacy = 'The Garden is the community app for UCity The Church. This policy explains what the app collects and how it is used.\n\nWhat we collect\n• Account details: your name and email address, used to sign you in and show your name on what you post.\n• What you share: events, volunteer sign-ups, RSVPs, prayer requests, needs and offers, and chat messages (including any photos or files you choose to attach).\n• Reports and blocks you make, so we can keep the community safe.\nWe do not collect your location, contacts, or advertising identifiers, and we do not track you across other apps or websites.\n\nHow it is used\nYour information is used only to run The Garden: signing you in, showing posts and events to other members, and delivering your messages. We do not sell your data or use it for advertising.\n\nWho can see it\nOther signed-in members can see your name and the things you post. Chat messages are visible only to the people in that conversation.\n\nServices we use\n• Google Firebase (authentication and database), which stores account and post data.\n• Stream (getstream.io), which stores and delivers chat messages.\nThese providers process data on our behalf under their own privacy and security terms.\n\nKeeping and deleting your data\nYour data is kept while your account is active. You can delete your account at any time in the app (Profile → Delete Account). This removes your profile, your prayer requests and needs/offers posts, and your chat account. You can also email us to ask for deletion.\n\nChildren\nThe Garden is not directed at children under 13, and we do not knowingly collect their information.\n\nContact\nQuestions or requests: {email}\n\nChanges\nIf this policy changes we will update it in the app and on this page.\n\nLast updated: October 13, 2026';

const _terms = 'The Garden is a place for the UCity The Church family to connect, pray, serve and help one another. By creating an account you agree to these guidelines.\n\nBe kind and respectful\nNo harassment, bullying, hate speech, threats, or personal attacks.\n\nKeep it appropriate\nNo sexual, violent, or otherwise objectionable content. There is zero tolerance for abusive content or users.\n\nBe honest\nNo spam, scams, impersonation, or misleading posts. Needs and offers should be genuine.\n\nRespect privacy\nDon\'t share other people\'s personal information or prayer requests outside the app without their permission.\n\nReporting and blocking\nUse the ••• menu on any post to report it or block its author, and the flag option on chat messages. Reports are reviewed within 24 hours; content that breaks these guidelines is removed and the people who posted it may be removed from the app.\n\nYour account\nYou are responsible for what you post. You can delete your account at any time from your profile.\n\nContact\n{email}';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});
  final LegalPage page;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = page == LegalPage.privacy;
    final text = (isPrivacy ? _privacy : _terms).replaceAll('{email}', AppConfig.supportEmail);
    return Scaffold(
      appBar: AppBar(title: Text(isPrivacy ? 'Privacy Policy' : 'Community Guidelines')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
      ),
    );
  }
}
