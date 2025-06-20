<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, javax.servlet.http.*, javax.servlet.*, java.security.MessageDigest, java.util.regex.Pattern" %>
<%@ include file="../db.jsp" %>

<%!
    // JSP declaration 영역 - 함수 선언
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
    String password_check = request.getParameter("password_check");
    String email = request.getParameter("email");
    String phonenum = request.getParameter("phonenum");

    // 0. 비밀번호 = 아이디 금지
    if (username.equals(password)) {
%>
    <script>
        alert('아이디와 비밀번호는 같을 수 없습니다.');
        history.back();
    </script>
<%
        return;
    }

    // 1. 비밀번호 확인
    if (!password.equals(password_check)) {
%>
    <script>
        alert('비밀번호가 일치하지 않습니다.');
        history.back();
    </script>
<%
        return;
    }

    // 2. 이메일 형식 검사 (정규식)
    String emailRegex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$";
    if (!Pattern.matches(emailRegex, email)) {
%>
    <script>
        alert('이메일 형식이 올바르지 않습니다.');
        history.back();
    </script>
<%
        return;
    }

    // 3. 전화번호 형식 검사 (정규식: 010-1234-5678)
    String phoneRegex = "^\\d{3}-\\d{3,4}-\\d{4}$";
    if (!Pattern.matches(phoneRegex, phonenum)) {
%>
    <script>
        alert('전화번호 형식이 올바르지 않습니다. 예: 010-1234-5678');
        history.back();
    </script>
<%
        return;
    }

    // 4. 비밀번호 해시 (SHA-512)
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
        // 5. 아이디 중복 체크
        String checkIdSql = "SELECT * FROM user_table WHERE user_id = ?";
        pstmt = db_conn.prepareStatement(checkIdSql);
        pstmt.setString(1, username);
        rs = pstmt.executeQuery();
        if (rs.next()) {
%>
    <script>
        alert('이미 등록된 ID입니다. 로그인 페이지로 이동합니다.');
        location.href = 'login.jsp';
    </script>
<%
            rs.close();
            pstmt.close();
            return;
        }
        rs.close();
        pstmt.close();

        // 6. 이메일 중복 체크
        String checkEmailSql = "SELECT * FROM user_table WHERE user_email = ?";
        pstmt = db_conn.prepareStatement(checkEmailSql);
        pstmt.setString(1, email);
        rs = pstmt.executeQuery();
        if (rs.next()) {
%>
    <script>
        alert('이미 등록된 이메일입니다.');
        history.back();
    </script>
<%
            rs.close();
            pstmt.close();
            return;
        }
        rs.close();
        pstmt.close();

        // 7. 전화번호 중복 체크
        String checkPhoneSql = "SELECT * FROM user_table WHERE user_phonenum = ?";
        pstmt = db_conn.prepareStatement(checkPhoneSql);
        pstmt.setString(1, phonenum);
        rs = pstmt.executeQuery();
        if (rs.next()) {
%>
    <script>
        alert('이미 등록된 전화번호입니다.');
        history.back();
    </script>
<%
            rs.close();
            pstmt.close();
            return;
        }
        rs.close();
        pstmt.close();

        // 8. 실제 회원정보 DB에 저장 (비밀번호는 해시로!)
        String insertSql = "INSERT INTO user_table (user_id, user_password, user_email, user_phonenum) VALUES (?, ?, ?, ?)";
        pstmt = db_conn.prepareStatement(insertSql);
        pstmt.setString(1, username);
        pstmt.setString(2, hashedPw);
        pstmt.setString(3, email);
        pstmt.setString(4, phonenum);

        int result = pstmt.executeUpdate();
        pstmt.close();

        if (result > 0) {
%>
    <script>
        alert('회원가입 성공!');
        location.href = 'login.jsp';
    </script>
<%
        } else {
            out.println("회원가입 실패: 데이터 삽입 오류");
        }
    } catch (Exception e) {
        out.println("DB 오류: " + e.getMessage());
    } finally {
        try { if (rs != null) rs.close(); } catch (Exception e) {}
        try { if (pstmt != null) pstmt.close(); } catch (Exception e) {}
        try { if (db_conn != null) db_conn.close(); } catch (Exception e) {}
    }
%>
