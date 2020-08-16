@IsTest
public class RemoteTrxContractLookupTest {

    @TestSetup
    public static void testSetup() {
        Test.startTest();
        Remote_Transaction__c trx = new Remote_Transaction__c();
        trx.Customer_Name__c = 'John';
        trx.Customer_Last_Name__c = 'Doe';
        trx.Customer_Email__c = 'test@test.com';
        trx.Status__c = 'Sent';
        trx.Type__c = 'Payment';
        insert trx;
    }
    
    @IsTest
    public static void testGetContractDetails(){
        List<RemoteTrxContractLookup.FlowInputs> request = new List<RemoteTrxContractLookup.FlowInputs>();
        RemoteTrxContractLookup.FlowInputs inp = new RemoteTrxContractLookup.FlowInputs();
        inp.leadNumber = '1-7199420868';
        inp.MVendorNumber = '50073203';
        inp.isServiceProvider = true;
        request.add(inp);
        
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource('Remote_Trx_ContractLookupMock');
        mock.setStatusCode(200);
        mock.setHeader('Content-Type', 'application/json;charset=UTF-8');
        Test.setMock(HttpCalloutMock.class, mock);
       	Test.startTest();
        List<RemoteTrxContractLookup.FlowOutput> response = RemoteTrxContractLookup.getContractDetails(request);
        Test.stopTest();
        System.assertEquals(2500, response[0].balanceDue, 'Balance due must be $2500');
    }
}