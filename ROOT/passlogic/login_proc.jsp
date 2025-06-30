<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, javax.servlet.http.*, javax.servlet.*, java.security.MessageDigest" %>
<%@ page session="true" %>
<%@ include file="../db.jsp" %>

<%!
    // [여기서 선언] JSP declaration 영역!
    String hashPassword(String pw) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-512");
        byte[] hash = md.digest(pw.getBytes("UTF-8"));
        StringBuilder sb = new StringBuilder();
        for (byte b : hash) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
%>
<%
    String username = request.getParameter("username");
    String password = request.getParameter("password");

    String hashedPw = "";
    try {
        hashedPw = hashPassword(password);
    } catch (Exception e) {
        out.println("해시 처리 오류: " + e.getMessage());
        return;
    }

    PreparedStatement pstmt = null;
    ResultSet rs = null;

    try {
        // [1] 관리자 계정은 잠금 검사 및 fail count 증가 건너뜀
        if ("admin".equals(username)) {
            String adminSql = "SELECT * FROM user_table WHERE user_id = ? AND user_password = ?";
            pstmt = db_conn.prepareStatement(adminSql);
            pstmt.setString(1, username);
            pstmt.setString(2, hashedPw);
            rs = pstmt.executeQuery();

            if (rs.next()) {
                // 로그인 성공 (관리자)
                session.setAttribute("idx", rs.getInt("user_idx"));
                session.setAttribute("username", rs.getString("user_id"));
                session.setAttribute("email", rs.getString("user_email"));
                session.setAttribute("phonenum", rs.getString("user_phonenum"));
                session.setAttribute("profile_image", rs.getString("profile_image") != null ? rs.getString("profile_image") : "img/profileshark.png");

                // ★ CSRF 토큰: 세션에 없으면 한 번만 발급
                if (session.getAttribute("csrf_token") == null) {
                    String csrf_token = java.util.UUID.randomUUID().toString().replace("-", "");
                    session.setAttribute("csrf_token", csrf_token);
                }

                Cookie jsid = new Cookie("JSESSIONID", session.getId());
                jsid.setPath("/");
                jsid.setHttpOnly(false);
                response.addCookie(jsid);

%>
<script>
    alert('환영합니다! 관리자님!');
    location.href = '../index.jsp';
</script>
<%
            } else {
%>
<script>
    alert('관리자 비밀번호가 올바르지 않습니다.');
    history.back();
</script>
<%
            }
            // 리턴 필수
            return;
        }

        // [2] 일반 계정: 잠금 및 fail count 적용
        String lockSql = "SELECT is_locked, login_fail_count FROM user_table WHERE user_id = ?";
        pstmt = db_conn.prepareStatement(lockSql);
        pstmt.setString(1, username);
        rs = pstmt.executeQuery();

        if (rs.next()) {
            boolean isLocked = rs.getInt("is_locked") == 1;
            int failCount = rs.getInt("login_fail_count");
            if (isLocked) {
%>
<script>
    alert('이 계정은 계정 잠금 상태입니다. 관리자에게 문의하세요.');
    history.back();
</script>
<%
                return;
            }
        } else {
%>
<script>
    alert('존재하지 않는 아이디입니다.');
    history.back();
</script>
<%
            return;
        }
        rs.close();
        pstmt.close();

        // 정상 로그인 시도
        String sql = "SELECT * FROM user_table WHERE user_id = ? AND user_password = ?";
        pstmt = db_conn.prepareStatement(sql);
        pstmt.setString(1, username);
        pstmt.setString(2, hashedPw);
        rs = pstmt.executeQuery();

        if (rs.next()) {
            String resetSql = "UPDATE user_table SET login_fail_count=0, is_locked=0 WHERE user_id=?";
            PreparedStatement resetPstmt = db_conn.prepareStatement(resetSql);
            resetPstmt.setString(1, username);
            resetPstmt.executeUpdate();
            resetPstmt.close();

            session.setAttribute("idx", rs.getInt("user_idx"));
            session.setAttribute("username", rs.getString("user_id"));
            session.setAttribute("email", rs.getString("user_email"));
            session.setAttribute("phonenum", rs.getString("user_phonenum"));
            session.setAttribute("profile_image", rs.getString("profile_image") != null ? rs.getString("profile_image") : "img/profileshark.png");

            // ★ CSRF 토큰: 세션에 없으면 한 번만 발급
            if (session.getAttribute("csrf_token") == null) {
                String csrf_token = java.util.UUID.randomUUID().toString().replace("-", "");
                session.setAttribute("csrf_token", csrf_token);
            }

            Cookie jsid = new Cookie("JSESSIONID", session.getId());
            jsid.setPath("/");
            jsid.setHttpOnly(false);
            response.addCookie(jsid);

            response.sendRedirect("../index.jsp");
        } else {
            String updateSql = "UPDATE user_table SET login_fail_count = login_fail_count + 1 WHERE user_id=?";
            PreparedStatement updatePstmt = db_conn.prepareStatement(updateSql);
            updatePstmt.setString(1, username);
            updatePstmt.executeUpdate();
            updatePstmt.close();

            String checkSql = "SELECT login_fail_count FROM user_table WHERE user_id=?";
            PreparedStatement checkPstmt = db_conn.prepareStatement(checkSql);
            checkPstmt.setString(1, username);
            ResultSet checkRs = checkPstmt.executeQuery();
            if (checkRs.next()) {
                int count = checkRs.getInt("login_fail_count");
                if (count >= 5) {
                    String lockUpdate = "UPDATE user_table SET is_locked=1 WHERE user_id=?";
                    PreparedStatement lockPstmt = db_conn.prepareStatement(lockUpdate);
                    lockPstmt.setString(1, username);
                    lockPstmt.executeUpdate();
                    lockPstmt.close();
%>
<script>
    alert('로그인 5회 이상 실패로 계정이 잠겼습니다. 관리자에게 문의하세요.');
    history.back();
</script>
<%
                    checkRs.close();
                    checkPstmt.close();
                    return;
                }
            }
            checkRs.close();
            checkPstmt.close();
%>
<script>
    alert('로그인 실패! 다시 입력하세요.');
    history.back();
</script>
<%
        }
    } catch (Exception e) {
        out.println("DB 오류: " + e.getMessage());
    } finally {
        try { if (rs != null) rs.close(); } catch (Exception e) {}
        try { if (pstmt != null) pstmt.close(); } catch (Exception e) {}
        try { if (db_conn != null) db_conn.close(); } catch (Exception e) {}
    }
%>
