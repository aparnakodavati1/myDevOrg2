@IsTest
public class RemoteTrxRequestCtrlTest {

    @TestSetup
    public static void testSetup() {
        Test.startTest();
        Remote_Transaction__c trx = new Remote_Transaction__c();
        trx.Customer_Name__c = 'John';
        trx.Customer_Last_Name__c = 'Doe';
        trx.Customer_Email__c = 'test@test.com';
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
    public static void testIsCommunity(){
        boolean isCommunity = RemoteTrxRequestCtrl.isCommunity();
        System.assertEquals(isCommunity, false, 'Site Should not be community');
    }
    
    @IsTest
    public static void testDeleteDocument(){
        ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion limit 1];
        RemoteTrxRequestCtrl.deleteDocument(contentVersion.ContentDocumentId);
        
        List<ContentVersion> contentVersion2 = [SELECT ContentDocumentId FROM ContentVersion];
        System.assertEquals(0, contentVersion2.size(), 'Should not found ContentVersion');
    }
    
    @IsTest
    public static void testDeleteRemoteTrx(){
        Remote_Transaction__c trx = [Select ID from Remote_Transaction__c limit 1];
        RemoteTrxRequestCtrl.deleteRemoteTrx(trx.Id);
        
        List<Remote_Transaction__c> trx2 = [Select ID, Encrypted_Id__c from Remote_Transaction__c];
        System.assertEquals(0, trx2.size(), 'Should not found RemoteTransaction');
    }
    
    @IsTest
    public static void testUploadDocumentsToPSPDF(){
        Test.setMock(HttpCalloutMock.class, new RemoteTrxPSPDFMock());
        Remote_Transaction__c trx = [Select ID from Remote_Transaction__c limit 1];
        test.StartTest();
        RemoteTrxFlowHelper.Response response = RemoteTrxRequestCtrl.uploadDocumentsToPSPDF(trx.Id);
        test.StopTest();
        System.assertEquals(true, response.isSuccess, 'Document should have been uploaded successfully');
    }
    
    
}