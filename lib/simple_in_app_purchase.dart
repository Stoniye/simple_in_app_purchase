import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

InAppPurchase get _iap => InAppPurchase.instance;
late StreamSubscription<List<PurchaseDetails>> _purchaseStreamSubscription;

bool initialized = false;

class BillingService {
  
  bool autoComplete = true;
  
  void Function(PurchaseData purchaseData)? handlePurchase;
  void Function(PurchaseData purchaseData)? purchaseUpdate;
  void Function(dynamic error)? purchaseError;
  void Function(PurchaseData purchaseData)? purchaseCompleted;

  Future<void> init() async {
    try {
      if (!await _iap.isAvailable()) {
        debugPrint('[simple_in_app_purchase] In-app purchase not available for this device.');
        return;
      }

      _purchaseStreamSubscription = _iap.purchaseStream.listen(_onPurchaseUpdated, onError: _onPurchaseError);

      initialized = true;
    } catch (e) {
      debugPrint('[simple_in_app_purchase] In-app purchase initialization failed: $e');
    }
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      purchaseUpdate!(toPurchaseData(purchase));
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handlePurchase(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('[simple_in_app_purchase] Purchase steam error: ${purchase.error}');
          break;

        default:
          break;
      }
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased){
      if (purchase.pendingCompletePurchase && autoComplete) {
        await InAppPurchase.instance.completePurchase(purchase);
        purchaseCompleted!(toPurchaseData(purchase));
      }
      handlePurchase!(toPurchaseData(purchase));
    }
  }

  void _onPurchaseError(dynamic error) {
    debugPrint('[simple_in_app_purchase] Purchase steam error: $error');
    purchaseUpdate!(error);
  }

  bool isInitialized() {
    if (!initialized) {
      debugPrint('[simple_in_app_purchase] In-app purchase not initialized. You have to call init() bevor using this service.');
      return false;
    }
    return true;
  }

  Future<void> buyItem(String productId) async {
    if (!isInitialized()) return;

    try {
      final productDetailsResponse = await _iap.queryProductDetails({productId});
      if (productDetailsResponse.productDetails.isEmpty) {
        debugPrint('[simple_in_app_purchase] Product not found: $productId');
        return;
      }

      final purchaseParam = PurchaseParam(productDetails: productDetailsResponse.productDetails.first);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[simple_in_app_purchase] Error buying item: $e');
    }
  }

  Future<void> buyItemAndConsume(String productId) async {
    if (!isInitialized()) return;

    try {
      final productDetailsResponse = await _iap.queryProductDetails({productId});
      if (productDetailsResponse.productDetails.isEmpty) {
        debugPrint('[simple_in_app_purchase] Product not found: $productId');
        return;
      }

      final purchaseParam = PurchaseParam(productDetails: productDetailsResponse.productDetails.first);
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[simple_in_app_purchase] Error buying item: $e');
    }
  }
  
  PurchaseData toPurchaseData(PurchaseDetails purchaseDetails){
    return PurchaseData(
      productId: purchaseDetails.purchaseID,
      pendingComplete: purchaseDetails.pendingCompletePurchase,
      status: purchaseDetails.status
    );
  }
}

class PurchaseData{
  String? productId;
  bool? pendingComplete;
  PurchaseStatus? status;
  
  PurchaseData({
    this.productId,
    this.pendingComplete,
    this.status,
  });
}