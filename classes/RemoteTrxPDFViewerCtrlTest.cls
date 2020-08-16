// dummy commit 06-12-20
@IsTest
public class RemoteTrxPDFViewerCtrlTest {
    
    @TestSetup
    public static void testSetup() {
        Test.startTest();
        Remote_Transaction__c trx = new Remote_Transaction__c();
        trx.Customer_Name__c = 'John';
        trx.Customer_Last_Name__c = 'Doe';
        trx.Customer_Email__c = 'test@test.com';
        trx.Status__c = 'Created';
        insert trx;
        
        ContentVersion cv = new ContentVersion();
        cv.pathOnClient = 'testPath';
        cv.Title = 'HVAC_Quote.pdf';
        cv.VersionData = Blob.valueOf('Test Document'); 
        cv.Entity_Id__c = trx.Id;
        insert cv;
        
        String contentDocID = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocID;
        cdl.LinkedEntityId = trx.Id;
        cdl.ShareType = 'V';
        insert cdl;

        Test.stopTest();
    }
    
    @IsTest
    public static void testGenerateJWTToken(){
        Remote_Transaction__c trx = [Select ID, Encrypted_Id__c from Remote_Transaction__c limit 1];
        PageReference myVfPage = Page.RemoteTrxPDFViewer;
        Test.setCurrentPage(myVfPage);
        String urlDecodedTrx = EncodingUtil.urlDecode(trx.Encrypted_Id__c, 'UTF-8');
        ApexPages.currentPage().getParameters().put('currentTrx', urlDecodedTrx);

        RemoteTrxPDFViewerCtrl pdfViewerCtrl = new RemoteTrxPDFViewerCtrl();
        String documentId = [SELECT ContentDocumentId FROM ContentVersion limit 1].ContentDocumentId;
        String jwt = pdfViewerCtrl.generateJWTToken(documentId);
        System.assert(String.isNotBlank(jwt), 'Unable to generate JWT Token!!. JWT Cannot be null!!.');
    }
    
    @IsTest
    public static void testUpdateTransactionStatus(){
        Remote_Transaction__c trx = [Select ID, Encrypted_Id__c from Remote_Transaction__c limit 1];
        Test.startTest();
        String urlDecodedTrx = EncodingUtil.urlDecode(trx.Encrypted_Id__c, 'UTF-8');
		RemoteTrxPDFViewerCtrl.updateTransactionStatus('Rejected', urlDecodedTrx, '', 
                                               'No Longer Interested', 'Reject Details');
        Test.stopTest();
        trx = [Select ID, Encrypted_Id__c,Status__c from Remote_Transaction__c limit 1];
        System.assertEquals('Rejected', trx.Status__c, 'Transaction status should be : Rejected');
    }
    
    @IsTest
    public static void testGetFromServer(){
        Remote_Transaction__c trx = [Select ID, Encrypted_Id__c, Status__c from Remote_Transaction__c limit 1];
        String urlDecodedTrx = EncodingUtil.urlDecode(trx.Encrypted_Id__c, 'UTF-8');
        RemoteTrxPDFViewerCtrl.RemoteTrxWrapper trxWrapper = RemoteTrxPDFViewerCtrl.getFromServer(urlDecodedTrx);
        System.assertEquals(trx.Status__c, trxWrapper.status, 'Transaction status should be : Created');
    }
}