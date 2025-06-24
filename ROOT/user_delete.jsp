<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ include file="db.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String username = (String) session.getAttribute("username");
    Integer selfUid = (Integer) session.getAttribute("idx");
    boolean isAdmin = "admin".equals(username);

    // [🚨 핵심 수정: 관리자용 CSRF 토큰과 일반 사용자 토큰 분기 처리]
    String expectedToken = isAdmin ? (String) session.getAttribute("admin_csrf_token")
                                   : (String) session.getAttribute("csrf_token");
    String submittedToken = request.getParameter("csrf_token");

    if (!"POST".equalsIgnoreCase(request.getMethod())
        || expectedToken == null || submittedToken == null
        || !submittedToken.equals(expectedToken)) {
%>
<script>
    alert('잘못된 접근입니다.');
    history.back();
</script>
<%
        return;
    }

    if (username == null || selfUid == null) {
%>
<script>
    alert('로그인 후 이용하세요.');
    location.href = 'index.jsp';
</script>
<%
        return;
    }

    int targetUid = selfUid;
    if (isAdmin && request.getParameter("uid") != null) {
        try {
            int maybe = Integer.parseInt(request.getParameter("uid"));
            if (maybe > 0) targetUid = maybe;
        } catch (Exception e) {}
    }

    PreparedStatement delete = db_conn.prepareStatement("DELETE FROM user_table WHERE user_idx = ?");
    delete.setInt(1, targetUid);
    delete.executeUpdate();

    if (!isAdmin || targetUid == selfUid) {
        session.invalidate();
%>
<script>
    alert('회원 탈퇴가 완료되었습니다.');
    window.location.href = 'index.jsp';
</script>
<%
    } else {
%>
<script>
    alert('회원이 삭제되었습니다.');
    window.location.href = 'admin/admin.jsp';
</script>
<%
    }
%>
