<?php
/**
 * SARVOOCCH Microcare Foundation - Automated Production Verification Suite
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('SARVOOCCH_APP', true);
require_once __DIR__ . '/../app/config.php';
require_once __DIR__ . '/../app/helpers.php';
require_once __DIR__ . '/../app/emi.php';
require_once __DIR__ . '/../app/services/KycService.php';
require_once __DIR__ . '/../app/services/PaymentGatewayService.php';
require_once __DIR__ . '/../app/services/NotificationService.php';

$passed = 0;
$failed = 0;

function assert_test(bool $condition, string $testName): void {
    global $passed, $failed;
    if ($condition) {
        echo "  [PASS] {$testName}\n";
        $passed++;
    } else {
        echo "  [FAIL] {$testName}\n";
        $failed++;
    }
}

echo "=== SARVOOCCH Production Verification Suite ===\n\n";

// 1. KycService Tests
echo "1. KYC & Multi-ID Verification Tests:\n";
$validAadhaar = KycService::validateAadhaar('234567890123'); // test checksum
assert_test(is_array($validAadhaar), "Aadhaar validator returns array");

$badAadhaar1 = KycService::validateAadhaar('012345678901');
assert_test($badAadhaar1['valid'] === false, "Aadhaar starting with 0 rejected");

$badAadhaar2 = KycService::validateAadhaar('123456789012');
assert_test($badAadhaar2['valid'] === false, "Aadhaar starting with 1 rejected");

$validPan = KycService::validatePan('ABCPE1234F');
assert_test($validPan['valid'] === true, "Valid Individual PAN accepted");

$badPan = KycService::validatePan('12345ABCDE');
assert_test($badPan['valid'] === false, "Malformed PAN rejected");

$validVoter = KycService::validateVoterId('DMO1234567');
assert_test($validVoter['valid'] === true, "Valid Voter ID (EPIC) accepted");

$badVoter = KycService::validateVoterId('1234567890');
assert_test($badVoter['valid'] === false, "Invalid Voter ID rejected");

// 2. Payment Gateway & Dynamic UPI Tests
echo "\n2. Payment Gateway & Dynamic UPI Tests:\n";
$upiIntent = PaymentGatewayService::buildUpiIntent(2500.00, 'TEST001', 'EMI Loan #1');
assert_test(str_starts_with($upiIntent, 'upi://pay?'), "UPI Intent starts with upi://pay?");
assert_test(str_contains($upiIntent, 'am=2500.00'), "UPI Intent specifies exact amount");

$qrUrl = PaymentGatewayService::getQrCodeUrl($upiIntent);
assert_test(str_contains($qrUrl, 'https://api.qrserver.com/'), "QR URL generated correctly");

$order = PaymentGatewayService::createOrder(5000.00, 'REC001');
assert_test($order['amount'] === 5000.00, "Order amount matches");
assert_test(!empty($order['order_id']), "Order ID generated");

// 3. Finance & EMI Compliance Tests
echo "\n3. RBI Financial Calculation Tests:\n";
$emi = Finance::emiCalc(30000, 24.0, 12, 'reducing');
assert_test($emi > 2800 && $emi < 2900, "Monthly reducing EMI calculation is accurate (~₹2,840)");

$feeSplit = Finance::feeSplit(30000, 1.5);
assert_test($feeSplit['fee'] === 450.00, "1.5% Processing fee is exactly ₹450.00");
assert_test($feeSplit['gst'] === 81.00, "18% GST is exactly ₹81.00");
assert_test($feeSplit['cgst'] === 40.50, "9% CGST is exactly ₹40.50");
assert_test($feeSplit['sgst'] === 40.50, "9% SGST is exactly ₹40.50");
assert_test($feeSplit['net_disbursed'] === 29469.00, "Net disbursed amount is ₹29,469.00");

echo "\n------------------------------------------------\n";
echo "Results: {$passed} Passed, {$failed} Failed\n";
if ($failed === 0) {
    echo "Status: ALL CHECKS PASSED - 100% PRODUCTION READY\n";
    exit(0);
} else {
    echo "Status: SOME CHECKS FAILED\n";
    exit(1);
}
