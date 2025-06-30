<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.*, java.security.MessageDigest, java.util.UUID" %>
<%@ include file="../db.jsp" %>
<%
    String username = (String) session.getAttribute("username");
    if (username == null || !"admin".equals(username)) {
%>
<script>
    alert('관리자만 접근 가능합니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }

    // [CSRF 토큰] 세션에 없으면 한 번만 생성
    String csrfToken = (String) session.getAttribute("csrf_token");
    if (csrfToken == null) {
        csrfToken = UUID.randomUUID().toString().replace("-", "");
        session.setAttribute("csrf_token", csrfToken);
    }

    int uid = 0;
    try {
        uid = Integer.parseInt(request.getParameter("uid"));
    } catch (Exception e) {
        uid = 0;
    }
    if (uid < 1) {
%>
<script>
    alert('잘못된 접근입니다.');
    location.href = 'admin.jsp';
</script>
<%
        return;
    }

    PreparedStatement ps = db_conn.prepareStatement(
        "SELECT user_id, user_email, user_phonenum, login_fail_count, is_locked FROM user_table WHERE user_idx = ?"
    );
    ps.setInt(1, uid);
    ResultSet rs = ps.executeQuery();
    if (!rs.next()) {
%>
<script>
    alert('존재하지 않는 회원입니다.');
    location.href = 'admin.jsp';
</script>
<%
        return;
    }
    String userId = rs.getString("user_id");
    String userEmail = rs.getString("user_email");
    String userPhone = rs.getString("user_phonenum");
    int failCount = rs.getInt("login_fail_count");
    int isLocked = rs.getInt("is_locked");

    // POST 요청 (회원정보 수정, 잠금/해제)
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String reqToken = request.getParameter("csrf_token");
        String sessToken = (String) session.getAttribute("csrf_token");
        if (sessToken == null || reqToken == null || !sessToken.equals(reqToken)) {
%>
<script>
    alert('잘못된 접근입니다.');
    location.href = 'admin.jsp';
</script>
<%
            return;
        }

        // 잠금 해제
        String unlock = request.getParameter("unlock");
        if ("1".equals(unlock)) {
            PreparedStatement unlockPs = db_conn.prepareStatement(
                "UPDATE user_table SET login_fail_count = 0, is_locked = 0 WHERE user_idx = ?"
            );
            unlockPs.setInt(1, uid);
            unlockPs.executeUpdate();
            unlockPs.close();
%>
<script>
    alert('계정 잠금이 해제되었습니다.');
    location.href = 'edit_user.jsp?uid=<%= uid %>';
</script>
<%
            return;
        }

        // 잠금(Ban) 기능
        String lock = request.getParameter("lock");
        if ("1".equals(lock)) {
            PreparedStatement lockPs = db_conn.prepareStatement(
                "UPDATE user_table SET is_locked = 1 WHERE user_idx = ?"
            );
            lockPs.setInt(1, uid);
            lockPs.executeUpdate();
            lockPs.close();
%>
<script>
    alert('계정이 잠금(벤)되었습니다.');
    location.href = 'edit_user.jsp?uid=<%= uid %>';
</script>
<%
            return;
        }

        // 회원 정보 수정
        String newId = request.getParameter("username").trim();
        String newEmail = request.getParameter("email").trim();
        String newPhone = request.getParameter("phonenum").trim();
        String newPw = request.getParameter("pw");

        // user_id 중복 체크
        PreparedStatement dupStmt = db_conn.prepareStatement(
            "SELECT COUNT(*) AS cnt FROM user_table WHERE user_id = ? AND user_idx != ?"
        );
        dupStmt.setString(1, newId);
        dupStmt.setInt(2, uid);
        ResultSet dupRs = dupStmt.executeQuery();
        if (dupRs.next() && dupRs.getInt("cnt") > 0) {
            dupRs.close();
            dupStmt.close();
%>
<script>
    alert('이미 사용 중인 아이디입니다.');
    history.back();
</script>
<%
            return;
        }
        dupRs.close();
        dupStmt.close();

        if (!newEmail.matches("^[A-Za-z0-9+_.-]+@(.+)$")) {
%>
<script>
    alert('이메일 형식이 올바르지 않습니다.');
    history.back();
</script>
<%
            return;
        }
        if (!newPhone.matches("\\d{3}-\\d{4}-\\d{4}")) {
%>
<script>
    alert('전화번호 형식이 올바르지 않습니다.');
    history.back();
</script>
<%
            return;
        }

        // 비밀번호/아이디 동일 금지
        if (newPw != null && !newPw.trim().isEmpty()) {
            if (newPw.equals(newId)) {
%>
<script>
    alert('비밀번호와 아이디는 다르게 설정해야 합니다.');
    history.back();
</script>
<%
                return;
            }
        }

        List<String> fields = new ArrayList<>();
        List<Object> params = new ArrayList<>();
        fields.add("user_id = ?");
        fields.add("user_email = ?");
        fields.add("user_phonenum = ?");
        params.add(newId);
        params.add(newEmail);
        params.add(newPhone);

        if (newPw != null && !newPw.trim().isEmpty()) {
            // SHA-512 해시 적용
            MessageDigest md = MessageDigest.getInstance("SHA-512");
            byte[] hashed = md.digest(newPw.getBytes("UTF-8"));
            StringBuilder sb = new StringBuilder();
            for (byte b : hashed) sb.append(String.format("%02x", b));
            String hashPw = sb.toString();
            fields.add("user_password = ?");
            params.add(hashPw);
        }

        String sql = "UPDATE user_table SET " + String.join(", ", fields) + " WHERE user_idx = ?";
        PreparedStatement update = db_conn.prepareStatement(sql);
        for (int i = 0; i < params.size(); i++) {
            update.setObject(i + 1, params.get(i));
        }
        update.setInt(params.size() + 1, uid);
        update.executeUpdate();
        update.close();
%>
<script>
    alert('수정 완료');
    location.href = 'admin.jsp';
</script>
<%
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>관리자 페이지 - 회원 수정</title>
    <link rel="icon" href="../img/sharks2.jpg" type="image/jpeg">
    <link rel="stylesheet" href="../style.css">
    <link rel="stylesheet" href="admin_style.css">
</head>
<body class="index-page">
<jsp:include page="../nav.jsp" />
<div class="main-box">
    <h1>회원 정보 수정 (ID: <%= userId %>)</h1>
    <form method="POST" action="">
        <input type="hidden" name="csrf_token" value="<%= csrfToken %>">
        <div class="input-group">
            <label for="username">이름</label>
            <input type="text" id="username" name="username" value="<%= userId %>" maxlength="30" required>
        </div>
        <div class="input-group">
            <label for="email">Email</label>
            <input type="email" id="email" name="email" value="<%= userEmail %>" required>
        </div>
        <div class="input-group">
            <label for="phonenum">PhoneNumber</label>
            <input type="text" id="phonenum" name="phonenum" value="<%= userPhone %>" required>
        </div>
        <div class="input-group">
            <label for="pw">새 비밀번호 변경</label>
            <input type="password" id="pw" name="pw" placeholder="변경할 비밀번호 입력">
        </div>
        <button type="submit">저장</button>
        <% if (userId.equals("admin")) { %>
            <span style="color:#888; font-weight:bold; margin-left:10px;">
                (관리자 계정은 잠금불가) 관리자 계정은 잠금할 수 없습니다.
            </span>
        <% } else if (failCount >= 5 || isLocked == 1) { %>
            <button type="submit" name="unlock" value="1" style="margin-left:10px;background-color:#27ae60;color:#fff;">잠금 해제</button>
            <span style="color:red; font-weight:bold;">
                현재 계정 잠금중
            </span>
        <% } else { %>
            <button type="submit" name="lock" value="1" style="margin-left:10px;background-color:#e74c3c;color:#fff;">잠금</button>
            <span style="color:gray; font-weight:normal;">
                계정이 정상 상태입니다.
            </span>
        <% } %>
    </form>
</div>
<script src="../js/modal.js"></script>
</body>
</html>
