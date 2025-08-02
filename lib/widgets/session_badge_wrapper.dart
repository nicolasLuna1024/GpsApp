import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/collaborative_session_bloc.dart';

class SessionBadgeWrapper extends StatelessWidget {
  final Widget child;

  const SessionBadgeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollaborativeSessionBloc, CollaborativeSessionState>(
      builder: (context, state) {
        bool hasActiveSessions = false;

        if (state is CollaborativeSessionLoaded) {
          hasActiveSessions = state.sessions.isNotEmpty;
        }

        if (!hasActiveSessions) {
          return child;
        }

        return Stack(
          children: [
            child,
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_work,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
