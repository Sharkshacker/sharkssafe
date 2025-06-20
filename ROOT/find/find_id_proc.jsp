<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ include file="../db.jsp" %>

<%
    request.setCharacterEncoding("UTF-8");

    // [1] 세션 기반 시도 횟수 제한 (예: 5회)
    Integer failCount = (Integer) session.getAttribute("find_id_fail");
    Long lockTime = (Long) session.getAttribute("find_id_lock_time");
    long now = System.currentTimeMillis();

    // 10분(600,000ms) 잠금 예시 + 남은 시간 안내
    if (lockTime != null && now < lockTime) {
        long remainSec = (lockTime - now) / 1000;
        long min = remainSec / 60;
        long sec = remainSec % 60;
%>
        <script>
            alert("아이디 찾기 시도 횟수를 초과했습니다.\n남은 대기 시간: <%= min %>분 <%= sec %>초\n10분 뒤 다시 시도해주세요.");
            location.href = "find_account.jsp";
        </script>
<%
        return;
    }

    if (failCount == null) failCount = 0;

    String email = request.getParameter("email");
    String phonenum = request.getParameter("phonenum");

    PreparedStatement pstmt = null;
    ResultSet rs = null;

    try {
        String sql = "SELECT user_id FROM user_table WHERE user_email = ? AND user_phonenum = ?";
        pstmt = db_conn.prepareStatement(sql);
        pstmt.setString(1, email);
        pstmt.setString(2, phonenum);

        rs = pstmt.executeQuery();

        if (rs.next()) {
            // [2] 성공 시 시도횟수 초기화
            session.removeAttribute("find_id_fail");
            session.removeAttribute("find_id_lock_time");
            String foundId = rs.getString("user_id");
%>
            <script>
                alert("회원님의 아이디는 [<%= foundId %>] 입니다.");
                location.href = "find_account.jsp";
            </script>
<%
        } else {
            // [3] 실패 시 시도횟수 증가
            failCount++;
            session.setAttribute("find_id_fail", failCount);

            if (failCount >= 5) {
                // 5회 초과 시 10분 잠금
                session.setAttribute("find_id_lock_time", now + 600_000L); // 10분(600,000ms)
%>
                <script>
                    alert("아이디 찾기 시도 횟수를 초과했습니다.\n10분 뒤 다시 시도해주세요.");
                    location.href = "find_account.jsp";
                </script>
<%
                return;
            }
%>
            <script>
                alert("입력하신 정보가 일치하지 않습니다. 다시 한 번 확인해주세요. [시도: <%= failCount %>/5]");
                history.back();
            </script>
<%
        }

    } catch (Exception e) {
%>
        <script>
            alert("오류가 발생했습니다. 다시 시도해주세요.");
            history.back();
        </script>
<%
    } finally {
        if (rs != null) try { rs.close(); } catch (Exception ignore) {}
        if (pstmt != null) try { pstmt.close(); } catch (Exception ignore) {}
    }
%>
