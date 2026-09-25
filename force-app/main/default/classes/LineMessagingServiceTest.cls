@IsTest
private class LineMessagingServiceTest {
  private class UnreachableMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      throw new CalloutException('Read timed out');
    }
  }

  @IsTest
  static void addressesCustomerByFirstNameThenLastName() {
    Assert.areEqual(
      'Hi Somchai,\n',
      LineMessagingService.addressAs('Somchai', 'Sukhumvit')
    );
    Assert.areEqual('Hi Meng,\n', LineMessagingService.addressAs(null, 'Meng'));
    Assert.areEqual(
      '',
      LineMessagingService.addressAs(null, 'LINE friend ae43')
    );
    Assert.areEqual('', LineMessagingService.addressAs(null, null));
  }

  @IsTest
  static void reportsCalloutFailure() {
    Test.setMock(HttpCalloutMock.class, new UnreachableMock());

    LineMessagingService.PushResult result = LineMessagingService.pushText(
      'U1',
      'hi'
    );

    Assert.isFalse(result.success);
    Assert.areEqual('Read timed out', result.error);
  }
}
