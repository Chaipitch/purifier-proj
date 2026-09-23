@IsTest
private class LineMessagingServiceTest {
  private class UnreachableMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      throw new CalloutException('Read timed out');
    }
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
