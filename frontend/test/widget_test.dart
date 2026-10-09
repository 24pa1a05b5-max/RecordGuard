import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/widgets/priority_badge.dart';
import 'package:frontend/shared/widgets/stat_card.dart';
import 'package:frontend/models/patient.dart';
import 'package:frontend/models/finding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/shared/widgets/finding_card.dart';
import 'package:frontend/shared/widgets/evidence_modal.dart';
import 'package:frontend/shared/widgets/review_modal.dart';

void main() {
  group('RecordGuard UI & Model Component Tests', () {
    testWidgets('StatusBadge renders label and icon correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Potential Contradiction',
              color: Colors.red,
              icon: Icons.warning,
            ),
          ),
        ),
      );

      expect(find.text('Potential Contradiction'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('StatCard displays metrics and triggers callback on tap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Pending Discrepancies',
              value: '4',
              subtitle: 'Awaiting clinical review',
              icon: Icons.warning_amber_rounded,
              accentColor: Colors.red,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('PENDING DISCREPANCIES'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Awaiting clinical review'), findsOneWidget);

      await tester.tap(find.byType(StatCard));
      expect(tapped, isTrue);
    });

    test('Patient model deserialization parses JSON accurately', () {
      final json = {
        'id': 'PAT-88201',
        'full_name': 'Eleanor Vance',
        'birth_date': '1968-04-12',
        'gender': 'Female',
        'mrn': 'SYN-88201',
        'is_synthetic': true,
        'notes': 'Scenario 1: Allergy conflict',
        'document_count': 2,
        'comparison_count': 1,
        'created_at': '2026-03-12T10:00:00Z',
      };

      final patient = Patient.fromJson(json);
      expect(patient.id, 'PAT-88201');
      expect(patient.fullName, 'Eleanor Vance');
      expect(patient.mrn, 'SYN-88201');
      expect(patient.documentCount, 2);
      expect(patient.comparisonCount, 1);
      expect(patient.isSynthetic, isTrue);
    });

    test('Finding model deserialization and classification formatting', () {
      final json = {
        'id': 'FND-001',
        'comparison_id': 'CMP-001',
        'patient_id': 'PAT-88201',
        'document_a_id': 'DOC-01',
        'document_b_id': 'DOC-02',
        'category': 'ALLERGY',
        'field_compared': 'Allergies',
        'statement_a_text': 'Penicillin allergy',
        'statement_b_text': 'No known drug allergies',
        'doc_a_name': 'docA.pdf',
        'doc_b_name': 'docB.pdf',
        'provider_a': 'Dr. Vance',
        'provider_b': 'Dr. Lin',
        'page_a': 1,
        'page_b': null,
        'unit_a': 'mg',
        'unit_b': 'mcg',
        'status_a': 'PRESENT',
        'status_b': 'DISCONTINUED',
        'uncertainty_notes': 'Document B is an unpaged record.',
        'clinically_verified': true,
        'verified_conclusion': 'Confirmed penicillin allergy.',
        'snippet_a': 'Penicillin allergy',
        'snippet_b': 'NKDA',
        'classification': 'POTENTIAL_CONTRADICTION',
        'priority_level': 'PRIORITY_REVIEW',
        'explanation': 'Conflicting allergy statements.',
        'recommendation': 'Verify with patient.',
        'current_status': 'CONFIRMED',
        'evidence_completeness': 1.0,
        'traceability_score': 1.0,
        'created_at': '2026-03-12T10:00:00Z',
      };

      final finding = Finding.fromJson(json);
      expect(finding.id, 'FND-001');
      expect(finding.documentAId, 'DOC-01');
      expect(finding.documentBId, 'DOC-02');
      expect(finding.pageA, 1);
      expect(finding.pageB, isNull);
      expect(finding.unitA, 'mg');
      expect(finding.statusB, 'DISCONTINUED');
      expect(finding.clinicallyVerified, isTrue);
      expect(finding.verifiedConclusion, 'Confirmed penicillin allergy.');
      expect(finding.classification, 'POTENTIAL_CONTRADICTION');
      expect(finding.classificationDisplay, 'Potential Contradiction');
    });

    testWidgets('FindingCard renders comparison details, snippets, and Page unavailable when unpaged', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finding = Finding(
        id: 'FND-TEST-01',
        comparisonId: 'CMP-01',
        patientId: 'PAT-88201',
        category: 'ALLERGY',
        fieldCompared: 'Allergies',
        statementAText: 'Penicillin allergy',
        statementBText: 'No known drug allergies',
        docAName: 'Metro_Discharge.pdf',
        docBName: 'Westside_Visit.txt',
        providerA: 'Metro General Hospital',
        providerB: 'Pinecrest Medical',
        dateA: '2026-03-12',
        dateB: '2026-03-15',
        pageA: 1,
        pageB: null, // Unpaged plain text
        snippetA: 'Penicillin allergy (hives)',
        snippetB: 'No known drug allergies (NKDA)',
        classification: 'POTENTIAL_CONTRADICTION',
        priorityLevel: 'PRIORITY_REVIEW',
        uncertaintyNotes: 'Doc B is unpaged plain text.',
        clinicallyVerified: true,
        verifiedConclusion: 'Severe urticaria confirmed.',
        explanation: 'Conflicting statements regarding penicillin allergy.',
        recommendation: 'Request professional clarification.',
        currentStatus: 'CONFIRMED',
        createdAt: '2026-03-15T12:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FindingCard(finding: finding),
            ),
          ),
        ),
      );

      expect(find.text('Potential Contradiction'), findsOneWidget);
      expect(find.text('Show Evidence'), findsOneWidget);
      expect(find.text('Clinician Verified'), findsOneWidget);
      expect(find.text('p.1'), findsOneWidget);
      expect(find.text('Page unavailable'), findsOneWidget); // Verifies truthful provenance!
      expect(find.textContaining('Severe urticaria confirmed.'), findsOneWidget);
      expect(find.textContaining('Doc B is unpaged plain text.'), findsOneWidget);
    });

    testWidgets('EvidenceModal displays side-by-side evidence, provenance, and full doc action', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finding = Finding(
        id: 'FND-TEST-02',
        comparisonId: 'CMP-02',
        patientId: 'PAT-88201',
        documentAId: 'DOC-101',
        documentBId: 'DOC-102',
        category: 'ALLERGY',
        fieldCompared: 'Allergies',
        statementAText: 'Penicillin allergy',
        statementBText: 'No known drug allergies',
        docAName: 'Metro_Discharge.pdf',
        docBName: 'Pinecrest_Intake.pdf',
        providerA: 'Metro General',
        providerB: 'Pinecrest Clinic',
        dateA: '2026-03-12',
        dateB: '2026-03-15',
        pageA: 1,
        pageB: 2,
        unitA: 'mg',
        unitB: null,
        snippetA: 'Exact quote Doc A',
        snippetB: 'Exact quote Doc B',
        classification: 'POTENTIAL_CONTRADICTION',
        priorityLevel: 'PRIORITY_REVIEW',
        traceabilityScore: 1.0,
        evidenceCompleteness: 1.0,
        explanation: 'Explanation text here',
        recommendation: 'Recommendation text here',
        currentStatus: 'PENDING_REVIEW',
        createdAt: '2026-03-15T12:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EvidenceModal(finding: finding),
            ),
          ),
        ),
      );

      expect(find.textContaining('Side-by-Side Evidence Provenance'), findsOneWidget);
      expect(find.textContaining('Exact quote Doc A'), findsOneWidget);
      expect(find.textContaining('Exact quote Doc B'), findsOneWidget);
      expect(find.text('100%'), findsNWidgets(2)); // Completeness and Traceability
      expect(find.text('Inspect Full Document'), findsNWidgets(2));
      expect(find.text('Explanation text here'), findsOneWidget);
    });

    testWidgets('ReviewModal renders action options, reason input, and enforces form validation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finding = Finding(
        id: 'FND-TEST-03',
        comparisonId: 'CMP-03',
        patientId: 'PAT-88201',
        category: 'ALLERGY',
        fieldCompared: 'Allergies',
        statementAText: 'Penicillin allergy',
        statementBText: 'No known drug allergies',
        docAName: 'Metro_Discharge.pdf',
        docBName: 'Pinecrest_Intake.pdf',
        providerA: 'Metro General',
        providerB: 'Pinecrest Clinic',
        snippetA: 'Penicillin allergy',
        snippetB: 'NKDA',
        classification: 'POTENTIAL_CONTRADICTION',
        priorityLevel: 'PRIORITY_REVIEW',
        explanation: 'Conflict',
        recommendation: 'Verify',
        currentStatus: 'PENDING_REVIEW',
        createdAt: '2026-03-15T12:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReviewModal(finding: finding),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Clinical Verification & Audit Log'), findsOneWidget);
      expect(find.text('Confirm Contradiction'), findsOneWidget);
      expect(find.text('Dismiss Contradiction'), findsOneWidget);
      expect(find.text('Save Verification'), findsOneWidget);

      // Attempt to submit with empty reason to trigger validation
      await tester.ensureVisible(find.text('Save Verification'));
      await tester.tap(find.text('Save Verification'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please provide a substantive rationale (min 3 characters).'),
        findsOneWidget,
      );
    });
  });
}
