/// The lifecycle of a submitted GCash payment proof, shown as a
/// tracker on the Subscription Status screen.
enum SubscriptionStep { submitted, underReview, approved, rejected }

/// Snapshot of a store's subscription/payment review, passed into
/// [SubscriptionStatusScreen].
class SubscriptionStatus {
  final SubscriptionStep currentStep;
  final DateTime submittedAt;
  final String? referenceNumber;
  final String? rejectionReason;

  const SubscriptionStatus({
    required this.currentStep,
    required this.submittedAt,
    this.referenceNumber,
    this.rejectionReason,
  });

  factory SubscriptionStatus.fromBackend(
    String status,
    DateTime submittedAt, {
    String? referenceNumber,
    String? rejectionReason,
  }) {
    final step = switch (status.toLowerCase()) {
      'approved' => SubscriptionStep.approved,
      'rejected' => SubscriptionStep.rejected,
      'under_review' => SubscriptionStep.underReview,
      _ => SubscriptionStep.submitted,
    };
    return SubscriptionStatus(
      currentStep: step,
      submittedAt: submittedAt,
      referenceNumber: referenceNumber,
      rejectionReason: rejectionReason,
    );
  }

  bool get isApproved => currentStep == SubscriptionStep.approved;
  bool get isRejected => currentStep == SubscriptionStep.rejected;
  bool get isPending =>
      currentStep == SubscriptionStep.submitted || currentStep == SubscriptionStep.underReview;

  /// "Pending review" / "Under review" / "Approved & active" / "Proof rejected"
  String get headline {
    switch (currentStep) {
      case SubscriptionStep.submitted:
        return 'Pending review';
      case SubscriptionStep.underReview:
        return 'Under review';
      case SubscriptionStep.approved:
        return 'Approved & active';
      case SubscriptionStep.rejected:
        return 'Proof rejected';
    }
  }
}

